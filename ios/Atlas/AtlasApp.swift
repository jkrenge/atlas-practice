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
    @State private var content: LearningContent?
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
                                    if let content { PackScreen(pack: pack, content: content) }
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
                        Label("Maps, flags, cities, and sights. Learn at your pace.", systemImage: "leaf")
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
                    let loaded = try await Task.detached(priority: .userInitiated) {
                        let library = try MapLibrary()
                        return (try LearningContent.load(), try MapLibrary.starterIDs.map(library.load))
                    }.value
                    content = loaded.0
                    packs = loaded.1
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
    let content: LearningContent
    @AppStorage("questionTimeLimit") private var secondsAllowed = 30
    @Environment(ProgressStore.self) private var progress
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Get to know\n\(pack.id == "nyc-boroughs" ? "New York City" : pack.manifest.name).")
                    .font(.system(.largeTitle, design: .serif, weight: .semibold))
                MapView(pack: pack, canvasHeight: 216, acceptsAnswers: false) { _ in }
                Text("CHOOSE HOW TO PRACTICE").font(.caption.weight(.semibold)).tracking(1.2).foregroundStyle(Color.atlasMuted)
                Picker("Time per question", selection: $secondsAllowed) {
                    Text("Untimed").tag(0)
                    Text("30 seconds").tag(30)
                    Text("60 seconds").tag(60)
                }.pickerStyle(.menu).accessibilityIdentifier("timer-setting")
                if pack.id == "nyc-neighborhoods-focused" {
                    Text("47 areas: 37 in Manhattan and 10 across the other boroughs. The larger groups are practice areas. Neighborhood boundaries are approximate.")
                        .font(.footnote).foregroundStyle(Color.atlasMuted)
                }
                if !content.states(in: pack).isEmpty {
                    NavigationLink { ReferenceScreen(pack: pack, content: content) } label: {
                        Label("Browse facts, cities & sights", systemImage: "book").frame(minHeight: 44)
                    }.accessibilityIdentifier("browse-facts")
                }
                ForEach(PracticeMode.available(in: pack)) { mode in
                    NavigationLink {
                        PracticeScreen(pack: pack, content: content, mode: mode, secondsAllowed: secondsAllowed)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: mode.symbol).font(.title2).frame(width: 32)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(mode.title).font(.headline)
                                Text(mode.instruction).font(.subheadline).foregroundStyle(Color.atlasMuted)
                                let record = progress.record(for: pack.id, mode: mode, secondsAllowed: secondsAllowed)
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
                    StudyScreen(pack: pack, content: content)
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
    let content: LearningContent
    @State private var session: PracticeSession
    @State private var timer: QuestionTimer
    @State private var paused = false
    @State private var guess: MapPin?
    @State private var showAreaList = false
    @State private var showCoordinateEntry = false
    @Environment(ProgressStore.self) private var progress
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    init(pack: MapPack, content: LearningContent, mode: PracticeMode, secondsAllowed: Int) {
        self.pack = pack
        self.content = content
        var ordered = false
        var seconds = secondsAllowed
        #if DEBUG
        ordered = ProcessInfo.processInfo.arguments.contains("--ui-testing")
        if ordered { seconds = ProcessInfo.processInfo.arguments.contains("--timer-test") ? 2 : 0 }
        #endif
        _session = State(initialValue: PracticeSession(areas: content.areas(in: pack, mode: mode), mode: mode,
                                                       ordered: ordered, secondsAllowed: seconds))
        _timer = State(initialValue: QuestionTimer(seconds: seconds))
    }
    private var tolerance: Double { pack.id == "us-states" ? 50 : 20 }
    private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }
    private var answering: Bool { session.answer == nil && !paused && !session.isComplete }
    private var answerName: String {
        guard let area = session.current?.area else { return "" }
        return session.mode == .capitalLocation ? (content.state(area.id)?.capital ?? area.name) : content.answerLabel(area, mode: session.mode)
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let question = session.current {
                        HStack {
                            Text(question.isReview ? "A SECOND LOOK" : session.mode.title.uppercased())
                                .font(.caption.weight(.bold)).tracking(1.2)
                            Spacer()
                            Text("\(session.index + 1) / \(session.questions.count)").monospacedDigit().font(.subheadline)
                        }.foregroundStyle(Color.atlasMuted)
                        if session.secondsAllowed > 0 { timerControls }
                        Text(content.prompt(question.area, mode: session.mode, areaType: pack.manifest.areaType))
                            .font(.system(.title, design: .serif, weight: .semibold))
                            .accessibilityIdentifier("questionPrompt")
                        if session.mode == .flag, let state = content.state(question.area.id), let image = LearningContent.flag(state) {
                            Image(uiImage: image).resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: 190)
                                .padding(18).background(.white, in: RoundedRectangle(cornerRadius: 18))
                                .accessibilityLabel("State flag to identify").accessibilityIdentifier("quiz-flag")
                        }
                        if session.mode == .nickname, let state = content.state(question.area.id) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("“\(state.nickname)”").font(.title2.weight(.medium))
                                Text(state.nicknameKind).font(.caption).foregroundStyle(Color.atlasMuted)
                            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                                .background(.white, in: RoundedRectangle(cornerRadius: 18))
                        }
                        if session.mode == .population, let place = content.place(question.area.id) {
                            Text("Residents within city boundaries · \(place.populationDate ?? "")")
                                .font(.subheadline).foregroundStyle(Color.atlasMuted)
                        }
                        if session.mode.isLocation {
                            Text("Tap to place a pin. Zoom in to adjust it. Within \(Int(tolerance)) km counts as correct.")
                                .font(.subheadline).foregroundStyle(Color.atlasMuted)
                        }
                        if session.mode.usesMap {
                            MapView(pack: pack,
                                    canvasHeight: min(440, max(300, geometry.size.width * (session.mode == .find ? 1.03 : 0.82))) - 44,
                                    resetID: question.id,
                                    highlight: !session.mode.isLocation && (session.mode == .name || session.answer != nil) ? question.area.id : nil,
                                    selected: session.answer?.selected?.id,
                                    revealLabels: session.answer != nil,
                                    acceptsAnswers: answering && (session.mode == .find || session.mode.isLocation),
                                    guess: guess,
                                    target: session.answer != nil && session.mode.isLocation ? content.location(question.area, mode: session.mode) : nil,
                                    onLocation: session.mode.isLocation ? { guess = $0 } : nil) { id in
                                if let area = pack.area(id) { session.submit(area) }
                            }
                        }
                        if let answer = session.answer {
                            feedback(answer, question: question)
                            Button("Continue") { session.advance() }
                                .buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("continue-session")
                        } else {
                            if paused { Text("Paused. Tap Resume when you are ready.").font(.headline) }
                            if session.mode.isLocation {
                                if let guess {
                                    Text("Your pin: \(guess.coordinate.latitude.formatted(.number.precision(.fractionLength(2)))), \(guess.coordinate.longitude.formatted(.number.precision(.fractionLength(2))))")
                                        .font(.caption).accessibilityIdentifier("guess-coordinate")
                                }
                                Button("Check location") {
                                    if let guess, let target = content.location(question.area, mode: session.mode) {
                                        session.submitLocation(guess, target: target, toleranceKM: tolerance)
                                    }
                                }.buttonStyle(PrimaryButtonStyle()).disabled(guess == nil || !answering)
                                    .accessibilityIdentifier("check-location")
                                Button("Enter coordinates") { showCoordinateEntry = true }
                                    .frame(minHeight: 44).disabled(!answering)
                                    .accessibilityHint("An alternative to placing a pin on the map")
                            } else if session.mode != .find {
                                VStack(spacing: 8) {
                                    ForEach(question.choices) { area in
                                        Button { session.submit(area) } label: {
                                            HStack {
                                                Text(content.answerLabel(area, mode: session.mode))
                                                Spacer()
                                                Image(systemName: "circle").foregroundStyle(Color.atlasMuted)
                                            }.padding(.horizontal, 18).frame(minHeight: 48)
                                                .background(.white, in: RoundedRectangle(cornerRadius: 14))
                                        }.buttonStyle(.plain).disabled(!answering).accessibilityIdentifier("choice-\(area.id)")
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
                            }.font(.subheadline.weight(.medium)).disabled(!answering)
                        }
                    } else { results }
                }.padding(20).frame(maxWidth: 860).frame(maxWidth: .infinity)
            }.background(Color.atlasPaper)
        }
        .foregroundStyle(Color.atlasInk)
        .navigationTitle(session.mode.title).navigationBarTitleDisplayMode(.inline)
        .onChange(of: session.isComplete) { _, complete in if complete { progress.save(session, map: pack.id) } }
        .onChange(of: session.current?.id) { _, _ in
            guess = nil; paused = false
            timer = QuestionTimer(seconds: session.secondsAllowed)
            if scenePhase == .active { timer.resume(now: now) }
        }
        .onChange(of: session.answer != nil) { _, answered in
            guard answered, let answer = session.answer else { return }
            timer.pause(now: now); showAreaList = false; showCoordinateEntry = false
            UIAccessibility.post(notification: .announcement,
                                 argument: "\(answer.timedOut ? "Time is up. " : "")\(answer.correct ? "Correct. " : "The answer is ")\(answerName).")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && answering { timer.resume(now: now) }
            else { timer.pause(now: now) }
        }
        .onDisappear { timer.pause(now: now) }
        .task {
            guard session.secondsAllowed > 0 else { return }
            if scenePhase == .active && answering { timer.resume(now: now) }
            while !Task.isCancelled && !session.isComplete {
                do { try await Task.sleep(for: .milliseconds(200)) } catch { break }
                if session.secondsAllowed > 0 && answering && scenePhase == .active {
                    var updated = timer
                    updated.tick(now: now)
                    if ceil(updated.remaining) != ceil(timer.remaining) || updated.expired { timer = updated }
                    if updated.expired { session.expire() }
                }
            }
        }
        .sheet(isPresented: $showAreaList) {
            AreaList(pack: pack, title: "Choose an area") { area in session.submit(area); showAreaList = false }
        }
        .sheet(isPresented: $showCoordinateEntry) {
            CoordinateEntry(pack: pack) { guess = $0; showCoordinateEntry = false }
        }
    }

    private var timerControls: some View {
        HStack {
            Label(paused ? "Timer paused" : "\(Int(ceil(timer.remaining))) seconds left", systemImage: "timer")
                .monospacedDigit().font(.subheadline.weight(.semibold)).accessibilityIdentifier("question-timer")
            Spacer()
            if session.answer == nil {
                Button(paused ? "Resume" : "Pause") {
                    if paused { timer.resume(now: now) } else { timer.pause(now: now) }
                    paused.toggle()
                }.frame(minWidth: 60, minHeight: 44).accessibilityIdentifier("pause-timer")
            }
        }
    }

    private func feedback(_ answer: PracticeSession.Answer, question: PracticeSession.Question) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(answer.timedOut ? "Time’s up." : answer.correct ? "That's right." : "Take another look.",
                  systemImage: answer.correct ? "checkmark.circle.fill" : "arrow.uturn.backward.circle")
                .font(.title3.weight(.semibold))
            if session.mode.isLocation {
                if let distance = answer.distanceKM {
                    Text("\(distance.formatted(.number.precision(.fractionLength(1)))) km from \(answerName).")
                        .accessibilityIdentifier("distance-feedback")
                } else { Text(answerName) }
                Text("A = answer · G = your guess").font(.subheadline)
                if let pin = answer.guess {
                    Text("Your guess: \(pin.coordinate.latitude.formatted(.number.precision(.fractionLength(2)))), \(pin.coordinate.longitude.formatted(.number.precision(.fractionLength(2))))")
                        .font(.caption)
                }
            } else if session.mode.usesMap {
                if !answer.correct, let selected = answer.selected { Text("You chose \(selected.name). It is shown in brown.") }
                Text("\(question.area.name) is outlined in dark green.")
            } else {
                Text("Answer: \(answerName)").font(.headline)
                if !answer.correct, let selected = answer.selected {
                    Text("You chose \(content.answerLabel(selected, mode: session.mode)).")
                }
                if session.mode == .population, let place = content.place(question.area.id) {
                    Text("\(place.populationDate ?? "") · \(place.populationDefinition ?? "City population")").font(.caption)
                }
            }
            if !answer.correct && !question.isReview {
                Text("You will see this place again in this session.").font(.footnote).foregroundStyle(Color.atlasMuted)
            }
        }.font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
            .padding(18).background(.white, in: RoundedRectangle(cornerRadius: 18))
            .accessibilityElement(children: .combine).accessibilityIdentifier("answerFeedback")
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: 24) {
            Image(systemName: "checkmark.seal").font(.system(size: 48, weight: .light)).foregroundStyle(Color.atlasTeal)
            Text("A little more\nof the world, learned.")
                .font(.system(.largeTitle, design: .serif, weight: .semibold))
            Text("\(session.firstAttemptCorrect) of \(session.primaryCount)")
                .font(.system(size: 48, weight: .semibold, design: .rounded)).accessibilityIdentifier("firstAttemptScore")
            Text("Correct on the first try").foregroundStyle(Color.atlasMuted)
            Text(session.secondsAllowed == 0 ? "Untimed practice" : "\(session.secondsAllowed) seconds per question")
                .font(.subheadline)
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

struct CoordinateEntry: View {
    let pack: MapPack
    let onSelect: (MapPin) -> Void
    @State private var latitude = ""
    @State private var longitude = ""
    @Environment(\.dismiss) private var dismiss
    private var coordinate: Coordinate? {
        guard let lat = Double(latitude.replacingOccurrences(of: ",", with: ".")),
              let lon = Double(longitude.replacingOccurrences(of: ",", with: ".")),
              (-90...90).contains(lat), (-180...180).contains(lon) else { return nil }
        return Coordinate(lon, lat)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Degrees · north and east are positive") {
                    TextField("Latitude", text: $latitude).accessibilityIdentifier("latitude-input")
                    TextField("Longitude", text: $longitude).accessibilityIdentifier("longitude-input")
                    Text("Use a minus sign for west or south. Example: 40.7, -74.0.").font(.caption)
                }
                Button("Place pin") {
                    guard let coordinate else { return }
                    let region = pack.id == "us-states" ?
                        (coordinate.latitude > 50 && (coordinate.longitude < -130 || coordinate.longitude > 0) ? "US-AK" :
                         coordinate.latitude < 25 && coordinate.longitude < -140 ? "US-HI" : "US-AL") : "DE-BY"
                    onSelect(MapPin(coordinate: coordinate, regionID: region))
                }.disabled(coordinate == nil).accessibilityIdentifier("place-coordinate-pin")
            }.navigationTitle("Enter your guess").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

struct StudyScreen: View {
    let pack: MapPack
    let content: LearningContent
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
                    if let selected, !pack.id.hasPrefix("nyc-") {
                        Text("Map label: \(selected.id.suffix(2))").font(.subheadline).foregroundStyle(Color.atlasMuted)
                    }
                    if let selected, let state = content.state(selected.id) { StateFactCard(state: state) }
                    Text("ALL \(pack.manifest.areaType.uppercased())S").font(.caption.weight(.semibold)).tracking(1)
                    ForEach(pack.areas.sorted { $0.name < $1.name }) { area in
                        Button { selected = area } label: {
                            HStack {
                                Text(area.name)
                                Spacer()
                                if !pack.id.hasPrefix("nyc-") { Text(String(area.id.suffix(2))).foregroundStyle(Color.atlasMuted) }
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
    @State private var search = ""
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List(pack.areas.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }.sorted { $0.name < $1.name }) { area in
                Button { onSelect(area) } label: {
                    Text(area.name).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                }.accessibilityIdentifier("area-\(area.id)")
            }.searchable(text: $search, prompt: "Search areas").navigationTitle(title).navigationBarTitleDisplayMode(.inline)
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
                Text("Boundaries: Natural Earth, Admin 1 states and provinces, version 5.1.1. The US map excludes large lakes so shorelines remain visible. Public domain. Boundaries are simplified for learning.")
                Link("Natural Earth", destination: URL(string: "https://www.naturalearthdata.com")!)
            }
            Section("New York City") {
                Text("Borough boundaries: NYC Department of City Planning, shore-clipped borough polygons, version 26B. These are the five official boroughs.")
                Link("NYC Open Data source", destination: URL(string: "https://data.cityofnewyork.us/d/gthc-hcne")!)
            }
            Section("NYC neighborhoods") {
                Text("37 Manhattan areas and 10 areas across the other boroughs. Bed-Stuy, DUMBO, Williamsburg, Greenpoint, and Long Island City stay separate. West Brooklyn, South & East Brooklyn, and Queens (other areas) are merged practice areas. The Bronx and Staten Island use official borough boundaries.")
                Text("Neighborhood geometry: Pediacities/Ontodia, from a pinned public mirror. Boundaries are approximate and include parks and islands. The Marine Park boundary was repaired before merging.")
                Text("The datHere catalog declares the Open Data Commons Attribution License. Its download could not be compared with the mirror, so exact source equivalence remains unconfirmed.")
                Link("Neighborhood catalog and attribution", destination: URL(string: "https://data.dathere.com/dataset/nyc-neighborhoods")!)
            }
            Section("Facts, flags, cities, and sights") {
                Text("State facts and geographic points: Wikidata, CC0. Flags: Wikimedia Commons, with file-specific credits in Browse facts. Nicknames and campaign slogans are identified separately.")
                Text("City populations: US Census Vintage 2025, July 1, 2025; Destatis, December 31, 2024. The figures use city or municipal boundaries, not metro areas.")
                Text("Landmarks are a curated collection of 50 US and 20 German sights. Large parks use the source reference point. Each detail page links to its source.")
                Link("US Census population tables", destination: URL(string: "https://www.census.gov/data/tables/time-series/demo/popest/2020s-total-cities-and-towns.html")!)
                Link("Destatis city populations", destination: URL(string: "https://service.destatis.de/DE/barchart_race/BarChartRace500k_Berlin_1955-2024.html")!)
            }
            Section("Map layout") {
                Text("Alaska and Hawaii appear in separate insets at different scales. The map uses geographic coordinates. It is intended for learning, not navigation.")
            }
            Section("Your progress") {
                Text("Practice results are saved only on this device. Each mode and timer setting has a separate score. First attempts and review answers are counted separately.")
            }
        }.navigationTitle("Sources and credits").navigationBarTitleDisplayMode(.inline)
    }
}
