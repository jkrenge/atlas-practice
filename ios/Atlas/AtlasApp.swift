import SwiftUI
import UIKit

@main
struct AtlasApp: App {
    @State private var progress = ProgressStore()
    var body: some Scene {
        WindowGroup {
            LibraryScreen()
                .environment(progress)
                .tint(.atlasTeal)
                .preferredColorScheme(.light)
        }
    }
}

struct LibraryScreen: View {
    @State private var packs: [MapPack] = []
    @State private var loadError: String?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack {
                        Image(systemName: "globe.americas.fill").font(.title2)
                        Text("ATLAS PRACTICE").font(.caption.weight(.bold)).tracking(2)
                        Spacer()
                    }.foregroundStyle(Color.atlasTeal)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("A little practice.\nA bigger world.")
                            .font(.system(.largeTitle, design: .serif, weight: .semibold))
                        Text("Learn the places around you, one map at a time.")
                            .font(.body).foregroundStyle(Color.atlasMuted)
                    }
                    if let loadError {
                        ContentUnavailableView("Maps could not load", systemImage: "map", description: Text(loadError))
                    } else if packs.isEmpty {
                        ProgressView("Opening your maps…")
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("CHOOSE YOUR MAP").font(.caption.weight(.semibold)).tracking(1.4).foregroundStyle(Color.atlasMuted)
                            ForEach(packs) { pack in
                                NavigationLink {
                                    PackScreen(pack: pack)
                                } label: {
                                    HStack(spacing: 16) {
                                        Image(systemName: symbol(pack.id))
                                            .font(.title2).frame(width: 48, height: 60)
                                            .foregroundStyle(Color.atlasTeal)
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(pack.id == "nyc-boroughs" ? "New York City" : pack.manifest.name)
                                                .font(.title3.weight(.semibold))
                                            Text("\(pack.areas.count) \(pack.manifest.areaType)s")
                                                .font(.subheadline).foregroundStyle(Color.atlasMuted)
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.up.right").font(.body.weight(.medium))
                                    }
                                    .padding(18).foregroundStyle(Color.atlasInk)
                                    .background(.white, in: RoundedRectangle(cornerRadius: 22))
                                }.buttonStyle(.plain).accessibilityIdentifier("map-\(pack.id)")
                            }
                        }
                        Label("A few questions. No timer. Room to learn.", systemImage: "leaf")
                            .font(.footnote).foregroundStyle(Color.atlasMuted)
                    }
                }
                .padding(24).frame(maxWidth: 700, alignment: .leading).frame(maxWidth: .infinity)
            }
            .background(Color.atlasPaper)
            .toolbar(.hidden, for: .navigationBar)
            .task {
                guard packs.isEmpty, loadError == nil else { return }
                do {
                    let library = try MapLibrary()
                    packs = try MapLibrary.starterIDs.map(library.load)
                } catch { loadError = error.localizedDescription }
            }
        }
    }
    private func symbol(_ id: String) -> String {
        switch id { case "us-states": "globe.americas"; case "germany-states": "globe.europe.africa"; default: "building.2" }
    }
}

struct PackScreen: View {
    let pack: MapPack
    @Environment(ProgressStore.self) private var progress
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Get to know\n\(pack.id == "nyc-boroughs" ? "New York City" : pack.manifest.name).")
                    .font(.system(.largeTitle, design: .serif, weight: .semibold))
                MapView(pack: pack, canvasHeight: 216, acceptsAnswers: false) { _ in }
                Text("CHOOSE HOW TO PRACTICE").font(.caption.weight(.semibold)).tracking(1.2).foregroundStyle(Color.atlasMuted)
                ForEach(PracticeMode.allCases) { mode in
                    NavigationLink {
                        PracticeScreen(pack: pack, mode: mode)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: mode.symbol).font(.title2).frame(width: 32)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(mode.title).font(.headline)
                                Text(mode.instruction).font(.subheadline).foregroundStyle(Color.atlasMuted)
                                let record = progress.record(for: pack.id, mode: mode)
                                if record.sessions > 0 {
                                    Text("\(record.firstCorrect)/\(record.firstTotal) correct on the first try")
                                        .font(.caption).foregroundStyle(Color.atlasTeal)
                                }
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.caption.weight(.bold))
                        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                            .background(.white, in: RoundedRectangle(cornerRadius: 20))
                    }.buttonStyle(.plain).accessibilityIdentifier("start-\(mode.rawValue)")
                }
                NavigationLink {
                    StudyScreen(pack: pack)
                } label: {
                    Label("Explore the map first", systemImage: "map")
                        .font(.headline).frame(maxWidth: .infinity, minHeight: 48)
                }.accessibilityIdentifier("study-map")
                Text("Sessions have up to 6 places, plus a second look at anything you miss. Progress stays on this device.")
                    .font(.footnote).foregroundStyle(Color.atlasMuted)
                NavigationLink { SourcesScreen() } label: {
                    Text("Map sources and credits").font(.footnote).frame(minHeight: 44).contentShape(Rectangle())
                }
            }.padding(20).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .background(Color.atlasPaper).foregroundStyle(Color.atlasInk)
        .navigationTitle(pack.id == "nyc-boroughs" ? "New York City" : pack.manifest.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}

struct PracticeScreen: View {
    let pack: MapPack
    @State private var session: PracticeSession
    @State private var showAreaList = false
    @Environment(ProgressStore.self) private var progress
    @Environment(\.dismiss) private var dismiss

    init(pack: MapPack, mode: PracticeMode) {
        self.pack = pack
        var ordered = false
        #if DEBUG
        ordered = ProcessInfo.processInfo.arguments.contains("--ui-testing")
        #endif
        _session = State(initialValue: PracticeSession(areas: pack.areas, mode: mode, ordered: ordered))
    }
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let question = session.current {
                        HStack {
                            Text(question.isReview ? "A SECOND LOOK" : "\(session.mode.title.uppercased())")
                                .font(.caption.weight(.bold)).tracking(1.2)
                            Spacer()
                            Text("\(session.index + 1) / \(session.questions.count)").monospacedDigit().font(.subheadline)
                        }.foregroundStyle(Color.atlasMuted)
                        Text(session.mode == .find ? "Find \(question.area.name)" : "Which \(pack.manifest.areaType) is this?")
                            .font(.system(.title, design: .serif, weight: .semibold))
                            .accessibilityIdentifier("questionPrompt")
                        MapView(pack: pack,
                                canvasHeight: min(440, max(300, geometry.size.width * (session.mode == .find ? 1.03 : 0.82))) - 44,
                                highlight: session.mode == .name || session.answer != nil ? question.area.id : nil,
                                selected: session.answer?.selected?.id,
                                revealLabels: session.answer != nil,
                                acceptsAnswers: session.mode == .find && session.answer == nil) { id in
                            if let area = pack.area(id) { session.submit(area) }
                        }
                        if let answer = session.answer {
                            VStack(alignment: .leading, spacing: 10) {
                                Label(answer.correct ? "That's right." : "Take another look.",
                                      systemImage: answer.correct ? "checkmark.circle.fill" : "arrow.uturn.backward.circle")
                                    .font(.title3.weight(.semibold))
                                if !answer.correct, let selected = answer.selected {
                                    Text("You chose \(selected.name). It is shown in brown.")
                                }
                                Text("\(question.area.name) is outlined in dark green.")
                                if !answer.correct && !question.isReview {
                                    Text("You will see this place again in this session.").font(.footnote).foregroundStyle(Color.atlasMuted)
                                }
                            }.font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                                .padding(18).background(.white, in: RoundedRectangle(cornerRadius: 18))
                                .accessibilityElement(children: .combine).accessibilityIdentifier("answerFeedback")
                            Button("Continue") { session.advance() }
                                .buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("continue-session")
                        } else {
                            if session.mode == .name {
                                VStack(spacing: 8) {
                                    ForEach(question.choices) { area in
                                        Button { session.submit(area) } label: {
                                            HStack { Text(area.name); Spacer(); Image(systemName: "circle").foregroundStyle(Color.atlasMuted) }
                                                .padding(.horizontal, 18).frame(minHeight: 48)
                                                .background(.white, in: RoundedRectangle(cornerRadius: 14))
                                        }.buttonStyle(.plain).accessibilityIdentifier("choice-\(area.id)")
                                    }
                                }
                            }
                            HStack {
                                Button { session.submit(nil) } label: {
                                    Text("Show answer").frame(minHeight: 44).contentShape(Rectangle())
                                }.accessibilityIdentifier("show-answer")
                                Spacer()
                                if session.mode == .find {
                                    Button { showAreaList = true } label: {
                                        Text("Use area list").frame(minHeight: 44).contentShape(Rectangle())
                                    }.accessibilityHint("An alternative to selecting an area on the map")
                                }
                            }.font(.subheadline.weight(.medium))
                        }
                    } else {
                        results
                    }
                }.padding(20).frame(maxWidth: 860).frame(maxWidth: .infinity)
            }.background(Color.atlasPaper)
        }
        .foregroundStyle(Color.atlasInk)
        .navigationTitle(session.mode.title).navigationBarTitleDisplayMode(.inline)
        .onChange(of: session.isComplete) { _, complete in if complete { progress.save(session, map: pack.id) } }
        .onChange(of: session.answer != nil) { _, answered in
            guard answered, let answer = session.answer, let question = session.current else { return }
            let choice = answer.selected.map { "You chose \($0.name). " } ?? ""
            UIAccessibility.post(notification: .announcement,
                                 argument: answer.correct ? "Correct. \(question.area.name)." : "\(choice)The answer is \(question.area.name).")
        }
        .sheet(isPresented: $showAreaList) {
            AreaList(pack: pack, title: "Choose an area") { area in session.submit(area); showAreaList = false }
        }
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: 24) {
            Image(systemName: "checkmark.seal").font(.system(size: 48, weight: .light)).foregroundStyle(Color.atlasTeal)
            Text("A little more\nof the world, learned.")
                .font(.system(.largeTitle, design: .serif, weight: .semibold))
            Text("\(session.firstAttemptCorrect) of \(session.primaryCount)")
                .font(.system(size: 48, weight: .semibold, design: .rounded))
                .accessibilityIdentifier("firstAttemptScore")
            Text("Correct on the first try").foregroundStyle(Color.atlasMuted)
            if !session.missed.isEmpty {
                Text("On review, you got \(session.reviewedCorrect) of \(session.missed.count) correct.")
                VStack(alignment: .leading, spacing: 10) {
                    Text("KEEP EXPLORING").font(.caption.weight(.bold)).tracking(1)
                    ForEach(session.missed) { area in Text(area.name) }
                }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white, in: RoundedRectangle(cornerRadius: 20))
            }
            Button("Back to map") { dismiss() }.buttonStyle(PrimaryButtonStyle())
        }.padding(.vertical, 24)
    }
}

struct StudyScreen: View {
    let pack: MapPack
    @State private var selected: Area?
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Look around.\nMake a few connections.")
                        .font(.system(.title, design: .serif, weight: .semibold))
                    Text("Tap an area to see its name. Zoom in for a closer look.")
                        .font(.subheadline).foregroundStyle(Color.atlasMuted)
                    MapView(pack: pack, canvasHeight: min(560, max(350, geometry.size.width)) - 44, highlight: selected?.id, revealLabels: true) { selected = pack.area($0) }
                    Text(selected?.name ?? "Choose an area on the map")
                        .font(.title2.weight(.semibold)).accessibilityIdentifier("study-selection")
                    if let selected, pack.id != "nyc-boroughs" {
                        Text("Map label: \(selected.id.suffix(2))").font(.subheadline).foregroundStyle(Color.atlasMuted)
                    }
                    Text("ALL \(pack.manifest.areaType.uppercased())S").font(.caption.weight(.semibold)).tracking(1)
                    ForEach(pack.areas.sorted { $0.name < $1.name }) { area in
                        Button { selected = area } label: {
                            HStack {
                                Text(area.name)
                                Spacer()
                                if pack.id != "nyc-boroughs" { Text(String(area.id.suffix(2))).foregroundStyle(Color.atlasMuted) }
                                if selected == area { Image(systemName: "checkmark.circle.fill") }
                            }.frame(minHeight: 44).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        Divider()
                    }
                }.padding(20).frame(maxWidth: 860).frame(maxWidth: .infinity)
            }.background(Color.atlasPaper)
        }.foregroundStyle(Color.atlasInk).navigationTitle("Explore the map").navigationBarTitleDisplayMode(.inline)
    }
}

struct AreaList: View {
    let pack: MapPack
    let title: String
    let onSelect: (Area) -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List(pack.areas.sorted { $0.name < $1.name }) { area in
                Button { onSelect(area) } label: {
                    Text(area.name).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                }.accessibilityIdentifier("area-\(area.id)")
            }.navigationTitle(title).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(.white).background(Color.atlasTeal.opacity(configuration.isPressed ? 0.8 : 1), in: Capsule())
    }
}

struct SourcesScreen: View {
    var body: some View {
        List {
            Section("United States and Germany") {
                Text("Boundaries: Natural Earth, Admin 1 states and provinces, version 5.1.1. Public domain. Boundaries are simplified for learning.")
                Link("Natural Earth", destination: URL(string: "https://www.naturalearthdata.com")!)
            }
            Section("New York City") {
                Text("Borough boundaries: NYC Department of City Planning, shore-clipped borough polygons, version 26B. These are the five official boroughs.")
                Link("NYC Open Data source", destination: URL(string: "https://data.cityofnewyork.us/d/gthc-hcne")!)
            }
            Section("Map layout") {
                Text("Alaska and Hawaii appear in separate insets at different scales. The map uses geographic coordinates. It is intended for learning, not navigation.")
            }
            Section("Your progress") {
                Text("Practice results are saved only on this device. Find the area and Name the area have separate scores. First attempts and review answers are counted separately.")
            }
        }.navigationTitle("Sources and credits").navigationBarTitleDisplayMode(.inline)
    }
}
