import SwiftUI
import UIKit

@main
struct AtlasApp: App {
    @State private var progress = ProgressStore()
    var body: some Scene {
        WindowGroup {
            LibraryScreen()
                .environment(progress)
                .tint(.atlasBlue)
                .preferredColorScheme(.light)
        }
    }
}

struct LibraryScreen: View {
    @State private var content: LearningContent?
    @State private var packs: [MapPack] = []
    @State private var loadError: String?
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    masthead
                    VStack(alignment: .leading, spacing: 12) {
                        Text("The world,\na little closer.")
                            .font(.custom("Georgia", size: 34, relativeTo: .largeTitle))
                            .tracking(-1).fixedSize(horizontal: false, vertical: true)
                        Text("Choose a map. Learn a little more.")
                            .font(.body).foregroundStyle(Color.atlasMuted)
                    }
                    if let loadError {
                        ContentUnavailableView("Maps could not load", systemImage: "map", description: Text(loadError))
                    } else if packs.isEmpty {
                        ProgressView("Opening your maps…")
                    } else {
                        VStack(alignment: .leading, spacing: 16) {
                            AtlasSectionLabel(title: "Your maps", detail: "\(packs.count) collections")
                            ForEach(Array(packs.enumerated()), id: \.element.id) { index, pack in
                                NavigationLink {
                                    if let content { PackScreen(pack: pack, content: content) }
                                } label: {
                                    LibraryMapLabel(pack: pack, featured: index == 0)
                                }
                                .buttonStyle(AtlasPressStyle())
                                .accessibilityIdentifier("map-\(pack.id)")
                                if index > 0 && index < packs.count - 1 { Divider().overlay(Color.atlasLine) }
                            }
                        }
                        Label("Made for curiosity. Ready wherever you are.", systemImage: "leaf")
                            .font(.footnote).foregroundStyle(Color.atlasMuted)
                    }
                }
                .padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 32)
                .frame(maxWidth: 700, alignment: .leading).frame(maxWidth: .infinity)
            }
            .background(Color.atlasPaper).foregroundStyle(Color.atlasInk)
            .toolbar(.hidden, for: .navigationBar)
            .task {
                guard packs.isEmpty, loadError == nil else { return }
                do {
                    let loaded = try await Self.loadContent()
                    content = loaded.0
                    packs = loaded.1
                } catch { loadError = error.localizedDescription }
            }
        }
    }

    @concurrent
    private static func loadContent() async throws -> sending (LearningContent, [MapPack]) {
        let library = try MapLibrary()
        return (try LearningContent.load(), try MapLibrary.starterIDs.map(library.load))
    }

    private var masthead: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            HStack(spacing: 8) {
                Image(systemName: "globe.americas").font(.title2).accessibilityHidden(true)
                Text("ATLAS").font(.subheadline.weight(.bold)).tracking(3).fixedSize().accessibilityLabel("Atlas")
            }
            if !typeSize.isAccessibilitySize { Spacer() }
            Label("Offline", systemImage: "checkmark.circle")
                .font(.caption.weight(.medium)).foregroundStyle(Color.atlasMuted)
        }.foregroundStyle(Color.atlasBlue)
    }

}

private struct LibraryMapLabel: View {
    let pack: MapPack
    let featured: Bool
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if featured {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("START EXPLORING").font(.caption2.weight(.bold)).tracking(1.8)
                        Spacer()
                        Image(systemName: "arrow.up.right").font(.body.weight(.medium))
                    }.foregroundStyle(Color.atlasPaper)
                    MapPreview(pack: pack).frame(height: 112).padding(.vertical, 8)
                    Text(pack.displayName).font(.custom("Georgia", size: 28, relativeTo: .title))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(pack.areas.count) \(pack.manifest.areaType)s · Capitals, flags & more")
                        .font(.subheadline).padding(.top, 6)
                }
                .padding(22).foregroundStyle(Color.atlasPaper)
                .background(Color.atlasBlue, in: RoundedRectangle(cornerRadius: 24))
            } else {
                HStack(spacing: 16) {
                    if !typeSize.isAccessibilitySize {
                        MapPreview(pack: pack).frame(width: 72, height: 72)
                            .background(Color.atlasSea, in: RoundedRectangle(cornerRadius: 12))
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(pack.displayName).font(.system(.title3, design: .serif, weight: .semibold))
                        Text("\(pack.areas.count) \(pack.manifest.areaType)s")
                            .font(.subheadline).foregroundStyle(Color.atlasMuted)
                    }.fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                        .foregroundStyle(Color.atlasBlue)
                }.padding(.vertical, 4).contentShape(Rectangle())
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(pack.displayName), \(pack.areas.count) \(pack.manifest.areaType)s")
    }
}

struct PackScreen: View {
    let pack: MapPack
    let content: LearningContent
    @AppStorage("questionTimeLimit") private var secondsAllowed = 30
    @AppStorage("practiceEntityCount") private var entityCount = 10
    @Environment(ProgressStore.self) private var progress
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    AtlasSectionLabel(title: "Your field guide", detail: "\(pack.areas.count) \(pack.manifest.areaType)s")
                    Text(pack.displayName)
                        .font(.custom("Georgia", size: 34, relativeTo: .largeTitle)).tracking(-0.8)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(spacing: 0) {
                    MapPreview(pack: pack).frame(height: 150).padding(.horizontal, 16)
                    let layout = typeSize >= .xxLarge
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
                        : AnyLayout(HStackLayout(spacing: 16))
                    layout {
                        NavigationLink { StudyScreen(pack: pack, content: content) } label: {
                            Label("Explore map", systemImage: "map")
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                        }.accessibilityIdentifier("study-map")
                        if !content.states(in: pack).isEmpty {
                            NavigationLink { ReferenceScreen(pack: pack, content: content) } label: {
                                Label("Browse facts", systemImage: "book.closed")
                                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                            }.accessibilityIdentifier("browse-facts")
                        }
                    }.font(.subheadline.weight(.semibold)).buttonStyle(AtlasPressStyle())
                        .padding(.horizontal, 18).padding(.vertical, 8)
                }.background(Color.atlasSea, in: RoundedRectangle(cornerRadius: 20))
                VStack(alignment: .leading, spacing: 12) {
                    ViewThatFits(in: .horizontal) {
                        HStack { Text("Practice at your pace").font(.headline); Spacer(); timerPicker }
                        VStack(alignment: .leading, spacing: 8) { Text("Practice at your pace").font(.headline); timerPicker }
                    }
                    HStack {
                        Text("Places per session").font(.subheadline)
                        Spacer()
                        Picker("Places per session", selection: $entityCount) {
                            Text("10").tag(10)
                            Text("25").tag(25)
                            Text("All").tag(0)
                        }.pickerStyle(.menu).frame(minHeight: 44)
                            .accessibilityIdentifier("session-length")
                    }
                    modeLink(.find, prominent: true)
                    Text("Uses all available places if fewer. Missed places return once for review.")
                        .font(.footnote).foregroundStyle(Color.atlasMuted)
                }
                modeSection("Names & facts", modes: PracticeMode.available(in: pack).filter { $0 != .find && !$0.isLocation })
                modeSection("Place a pin", modes: PracticeMode.available(in: pack).filter(\.isLocation))
                if pack.id == "nyc-neighborhoods-focused" {
                    Text("47 areas: 37 in Manhattan and 10 across the other boroughs. The larger groups are practice areas. Neighborhood boundaries are approximate.")
                        .font(.footnote).foregroundStyle(Color.atlasMuted)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Label("Your progress stays on this device.", systemImage: "iphone")
                        .font(.footnote).foregroundStyle(Color.atlasMuted)
                    NavigationLink { SourcesScreen() } label: {
                        Text("Map sources and credits").font(.footnote).frame(minHeight: 44).contentShape(Rectangle())
                    }
                }
            }.padding(24).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .background(Color.atlasPaper).foregroundStyle(Color.atlasInk)
        .navigationTitle("Practice").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    @ViewBuilder private func modeSection(_ title: String, modes: [PracticeMode]) -> some View {
        if !modes.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                AtlasSectionLabel(title: title).padding(.bottom, 8)
                ForEach(modes) { mode in
                    modeLink(mode)
                    Divider().overlay(Color.atlasLine)
                }
            }
        }
    }

    private var timerPicker: some View {
        Picker("Time per question", selection: $secondsAllowed) {
            Text("Untimed").tag(0)
            Text("30 seconds").tag(30)
            Text("60 seconds").tag(60)
        }
        .pickerStyle(.menu).font(.subheadline.weight(.medium))
        .frame(minHeight: 44).accessibilityIdentifier("timer-setting")
    }

    private func modeLink(_ mode: PracticeMode, prominent: Bool = false) -> some View {
        NavigationLink {
            PracticeScreen(pack: pack, content: content, mode: mode, secondsAllowed: secondsAllowed, entityCount: entityCount)
        } label: {
            HStack(spacing: 16) {
                if !prominent { Image(systemName: mode.symbol).font(.title3).frame(width: 28).foregroundStyle(Color.atlasBlue) }
                VStack(alignment: .leading, spacing: 6) {
                    Text(mode.title).font(.headline)
                    Text(mode.instruction).font(.subheadline)
                        .foregroundStyle(prominent ? Color.atlasPaper : Color.atlasMuted)
                    let record = progress.record(for: pack.id, mode: mode, secondsAllowed: secondsAllowed)
                    if record.sessions > 0 {
                        Text("\(record.firstCorrect)/\(record.firstTotal) correct on the first try")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(prominent ? Color.atlasPaper : Color.atlasBlue)
                    }
                }.fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: prominent ? "arrow.right" : "chevron.right")
                    .font(prominent ? .body.weight(.semibold) : .caption.weight(.semibold))
            }
            .padding(.horizontal, prominent ? 20 : 0).padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            .foregroundStyle(prominent ? Color.atlasPaper : Color.atlasInk)
            .background(prominent ? Color.atlasBlue : .clear, in: RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(AtlasPressStyle()).accessibilityIdentifier("start-\(mode.rawValue)")
    }
}

extension MapPack {
    var displayName: String { id == "nyc-boroughs" ? "New York City" : manifest.name }
}

struct AtlasSectionLabel: View {
    let title: String
    var detail: String? = nil
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) { heading; Spacer(); detailText }
            VStack(alignment: .leading, spacing: 6) { heading; detailText }
        }.foregroundStyle(Color.atlasMuted)
    }
    private var heading: some View { Text(title.uppercased()).font(.caption.weight(.bold)).tracking(1.5) }
    @ViewBuilder private var detailText: some View { if let detail { Text(detail).font(.caption) } }
}

struct AtlasPressStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(!isEnabled ? 0.5 : configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(configuration.isPressed ? nil : .spring(response: 0.3, dampingFraction: 1), value: configuration.isPressed)
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
    @State private var answerContentHeight: CGFloat = 0
    @State private var autoAdvanceSeconds = 3
    @Environment(ProgressStore.self) private var progress
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize

    init(pack: MapPack, content: LearningContent, mode: PracticeMode, secondsAllowed: Int, entityCount: Int) {
        self.pack = pack
        self.content = content
        var ordered = false
        var seconds = secondsAllowed
        #if DEBUG
        ordered = ProcessInfo.processInfo.arguments.contains("--ui-testing")
        if ordered { seconds = ProcessInfo.processInfo.arguments.contains("--timer-test") ? 2 : 0 }
        #endif
        let areas = content.areas(in: pack, mode: mode)
        _session = State(initialValue: PracticeSession(areas: areas, mode: mode, count: entityCount == 0 ? areas.count : entityCount,
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
            VStack(spacing: 0) {
                if let question = session.current {
                    questionBar(question)
                    if session.mode.usesMap {
                        MapView(pack: pack, canvasHeight: nil, fullscreen: true,
                                resetID: question.id,
                                highlight: !session.mode.isLocation && (session.mode == .name || session.answer != nil) ? question.area.id : nil,
                                selected: session.answer?.selected?.id,
                                acceptsAnswers: answering && (session.mode == .find || session.mode.isLocation),
                                guess: guess,
                                target: session.answer != nil && session.mode.isLocation ? content.location(question.area, mode: session.mode) : nil,
                                onLocation: session.mode.isLocation ? { guess = $0 } : nil) { id in
                            if let area = pack.area(id) { session.submit(area) }
                        }.frame(maxWidth: .infinity, maxHeight: .infinity)
                            .overlay(alignment: .top) {
                                if session.mode == .find {
                                    Text(content.prompt(question.area, mode: session.mode, areaType: pack.manifest.areaType))
                                        .font(.title2.weight(.bold))
                                        .multilineTextAlignment(.center)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 20).padding(.vertical, 12)
                                        .background(Color.atlasBlue, in: RoundedRectangle(cornerRadius: 18))
                                        .shadow(color: Color.atlasInk.opacity(0.15), radius: 6, y: 3)
                                        .padding(16)
                                        .allowsHitTesting(false)
                                        .accessibilityIdentifier("map-questionPrompt")
                                }
                            }
                            .ignoresSafeArea(.container, edges: .horizontal)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                Text(content.prompt(question.area, mode: session.mode, areaType: pack.manifest.areaType))
                                    .font(.title2.weight(.semibold)).accessibilityIdentifier("questionPrompt")
                                questionClue(question)
                            }.padding(24).frame(maxWidth: 760).frame(maxWidth: .infinity)
                        }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    answerPanel(question, maximumHeight: geometry.size.height * 0.40, compact: geometry.size.width > geometry.size.height)
                } else {
                    ScrollView { results.padding(20).frame(maxWidth: 760).frame(maxWidth: .infinity) }
                }
            }
        }
        .background(session.mode.usesMap && !session.isComplete ? Color.atlasSea : Color.atlasPaper)
        .foregroundStyle(Color.atlasInk)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: session.isComplete) { _, complete in if complete { progress.save(session, map: pack.id) } }
        .onChange(of: session.current?.id) { _, _ in
            guess = nil; paused = false
            timer = QuestionTimer(seconds: session.secondsAllowed)
            if scenePhase == .active { timer.resume(now: now) }
        }
        .onChange(of: session.answer != nil) { _, answered in
            guard answered, let answer = session.answer else { return }
            timer.pause(now: now); showAreaList = false; showCoordinateEntry = false
            UINotificationFeedbackGenerator().notificationOccurred(answer.correct ? .success : .warning)
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
        .task(id: scenePhase == .active && session.mode == .find && session.answer?.correct == true ? session.current?.id : nil) {
            guard scenePhase == .active, session.mode == .find, session.answer?.correct == true else { return }
            let questionID = session.current?.id
            autoAdvanceSeconds = 3
            for _ in 0..<3 {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                guard session.current?.id == questionID, session.answer?.correct == true else { return }
                autoAdvanceSeconds -= 1
            }
            session.advance()
        }
        .sheet(isPresented: $showAreaList) {
            AreaList(pack: pack, title: "Choose an area") { area in session.submit(area); showAreaList = false }
        }
        .sheet(isPresented: $showCoordinateEntry) {
            CoordinateEntry(pack: pack) { guess = $0; showCoordinateEntry = false }
        }
    }

    private func questionBar(_ question: PracticeSession.Question) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 12) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left").font(.body.weight(.semibold))
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }.accessibilityLabel("Back to practice").accessibilityIdentifier("leave-practice")
                Text(session.mode.usesMap ? content.prompt(question.area, mode: session.mode, areaType: pack.manifest.areaType) : session.mode.title)
                    .font(.headline).fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier(session.mode.usesMap ? "questionPrompt" : "practice-title")
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(session.index + 1) / \(session.questions.count)")
                        .font(.caption.weight(.semibold)).monospacedDigit()
                        .accessibilityLabel("Question \(session.index + 1) of \(session.questions.count)")
                    if session.secondsAllowed > 0 {
                        Text(paused ? "Paused" : "\(Int(ceil(timer.remaining)))s")
                            .font(.caption).monospacedDigit().accessibilityIdentifier("question-timer")
                            .accessibilityLabel(paused ? "Timer paused" : "\(Int(ceil(timer.remaining))) seconds left")
                    } else if question.isReview { Text("Review").font(.caption2) }
                }.foregroundStyle(Color.atlasMuted).fixedSize()
                if session.secondsAllowed > 0 && session.answer == nil {
                    Button {
                        if paused { timer.resume(now: now) } else { timer.pause(now: now) }
                        paused.toggle()
                    } label: {
                        Image(systemName: paused ? "play.fill" : "pause.fill")
                            .font(.subheadline).frame(width: 44, height: 44).contentShape(Rectangle())
                    }.accessibilityLabel(paused ? "Resume" : "Pause").accessibilityIdentifier("pause-timer")
                }
            }
            ProgressView(value: Double(session.answeredCount), total: Double(session.questions.count))
                .tint(Color.atlasBlue).accessibilityHidden(true)
        }.padding(.horizontal, 8).padding(.bottom, 8)
            .background(Color.atlasPaper)
    }

    @ViewBuilder private func questionClue(_ question: PracticeSession.Question) -> some View {
        if session.mode == .flag, let state = content.state(question.area.id), let image = LearningContent.flag(state) {
            Image(uiImage: image).resizable().scaledToFit().frame(maxWidth: 420, maxHeight: 250)
                .accessibilityLabel("State flag to identify").accessibilityIdentifier("quiz-flag")
        }
        if session.mode == .nickname, let state = content.state(question.area.id) {
            VStack(alignment: .leading, spacing: 10) {
                Text("“\(state.nickname)”").font(.title2.weight(.medium))
                Text(state.nicknameKind).font(.caption).foregroundStyle(Color.atlasMuted)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        if session.mode == .population, let place = content.place(question.area.id) {
            Text("Residents within city boundaries · \(place.populationDate ?? "")")
                .font(.subheadline).foregroundStyle(Color.atlasMuted)
        }
    }

    private func answerPanel(_ question: PracticeSession.Question, maximumHeight: CGFloat, compact: Bool) -> some View {
        let hasContent = session.answer != nil || session.mode != .find || paused
        let horizontal = (compact || session.answer != nil) && !typeSize.isAccessibilitySize
        let layout = horizontal ? AnyLayout(HStackLayout(alignment: .center, spacing: 16)) : AnyLayout(VStackLayout(spacing: 8))
        return layout {
            if hasContent {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        if let answer = session.answer {
                            feedback(answer, question: question)
                        } else {
                            if paused { Text("Paused. Tap Resume when you are ready.").font(.subheadline) }
                            if session.mode.isLocation {
                                Text(guess == nil ? "Tap to place a pin · Within \(Int(tolerance)) km counts" : "Pin placed · Tap the map to adjust")
                                    .font(.caption).foregroundStyle(Color.atlasMuted)
                                    .accessibilityIdentifier("guess-coordinate")
                            } else if session.mode != .find {
                                answerChoices(question, compact: compact)
                            }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { answerContentHeight = $0 }
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(height: min(answerContentHeight, maximumHeight))
                .frame(maxWidth: .infinity)
            }
            VStack(spacing: 8) {
                if session.answer != nil || session.mode.isLocation { primaryAction }
                if session.answer == nil {
                    HStack {
                        Button { session.submit(nil) } label: {
                            Text("Show answer").frame(minHeight: 44).contentShape(Rectangle())
                        }.accessibilityIdentifier("show-answer")
                        Spacer()
                        if session.mode == .find {
                            Button { showAreaList = true } label: {
                                Text("Use area list").frame(minHeight: 44).contentShape(Rectangle())
                            }.accessibilityHint("An alternative to selecting an area on the map")
                        } else if session.mode.isLocation {
                            Button { showCoordinateEntry = true } label: {
                                Text("Enter coordinates").frame(minHeight: 44).contentShape(Rectangle())
                            }.accessibilityHint("An alternative to placing a pin on the map")
                        }
                    }.font(.subheadline.weight(.medium)).buttonStyle(AtlasPressStyle()).disabled(!answering)
                }
            }.frame(width: horizontal && hasContent ? (session.mode.isLocation && session.answer == nil ? 260 : 132) : nil)
        }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)
            .frame(maxWidth: 760).frame(maxWidth: .infinity)
            .background(Color.atlasSurface)
    }

    private func answerChoices(_ question: PracticeSession.Question, compact: Bool) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: typeSize.isAccessibilitySize ? 1 : compact ? 4 : 2), spacing: 8) {
            ForEach(question.choices) { area in
                Button { session.submit(area) } label: {
                    Text(content.answerLabel(area, mode: session.mode))
                        .font(.subheadline.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, minHeight: 44).padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.atlasPaper, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.atlasLine, lineWidth: 1))
                }.buttonStyle(AtlasPressStyle()).disabled(!answering).accessibilityIdentifier("choice-\(area.id)")
            }
        }
    }

    @ViewBuilder private var primaryAction: some View {
        if session.answer != nil {
            Button("Continue") { session.advance() }
                .buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("continue-session")
        } else {
            Button("Check location") {
                if let guess, let area = session.current?.area, let target = content.location(area, mode: session.mode) {
                    session.submitLocation(guess, target: target, toleranceKM: tolerance)
                }
            }.buttonStyle(PrimaryButtonStyle()).disabled(guess == nil || !answering)
                .accessibilityIdentifier("check-location")
        }
    }

    private func feedback(_ answer: PracticeSession.Answer, question: PracticeSession.Question) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(answer.timedOut ? "Time’s up." : answer.correct ? "That's right." : "Take another look.",
                  systemImage: answer.correct ? "checkmark.circle.fill" : "arrow.uturn.backward.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(answer.correct ? Color.atlasBlue : Color.atlasClay)
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
                Text("Answer: \(question.area.name)").font(.headline)
                if session.mode == .find && answer.correct {
                    Text("Next area in \(autoAdvanceSeconds)s").font(.caption).monospacedDigit()
                }
                if !answer.correct, let selected = answer.selected { Text("You chose \(selected.name). It is shown in brown.") }
            } else {
                Text("Answer: \(answerName)").font(.headline)
                if !answer.correct, let selected = answer.selected {
                    Text("You chose \(content.answerLabel(selected, mode: session.mode)).")
                }
                if session.mode == .population, let place = content.place(question.area.id) {
                    Text("\(place.populationDate ?? "") · \(place.populationDefinition ?? "City population")").font(.caption)
                }
            }
        }.font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine).accessibilityIdentifier("answerFeedback")
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: 28) {
            Label("SESSION COMPLETE", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(Color.atlasBlue)
            Text("A little more\nof the world, learned.")
                .font(.custom("Georgia", size: 34, relativeTo: .largeTitle))
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text("First try").font(.headline)
                    Spacer()
                    Text("\(session.firstAttemptCorrect) of \(session.primaryCount)")
                        .font(.title2.weight(.semibold)).monospacedDigit().accessibilityIdentifier("firstAttemptScore")
                }
                if !session.missed.isEmpty {
                    Divider()
                    HStack(alignment: .firstTextBaseline) {
                        Text("On review").font(.headline)
                        Spacer()
                        Text("\(session.reviewedCorrect) of \(session.missed.count)").font(.title2.weight(.semibold)).monospacedDigit()
                    }
                }
                Text(session.secondsAllowed == 0 ? "Untimed practice" : "\(session.secondsAllowed) seconds per question")
                    .font(.subheadline).foregroundStyle(Color.atlasMuted)
            }.padding(22).background(Color.atlasSea, in: RoundedRectangle(cornerRadius: 20))
            if !session.missed.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    AtlasSectionLabel(title: "Keep exploring")
                    ForEach(session.missed) { area in
                        Text(area.name)
                        Divider()
                    }
                }
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
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).padding(.horizontal, 20).padding(.vertical, 16)
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(isEnabled ? Color.atlasPaper : Color.atlasMuted)
            .background(isEnabled ? Color.atlasBlue : Color.atlasLine, in: RoundedRectangle(cornerRadius: 16))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(configuration.isPressed ? nil : .spring(response: 0.3, dampingFraction: 1), value: configuration.isPressed)
    }
}

struct SourcesScreen: View {
    var body: some View {
        List {
            Section("United States and Germany") {
                Text("Boundaries: Natural Earth, Admin 1 states and provinces, version 5.1.1. State maps exclude mapped lakes using Natural Earth Lakes, version 5.0.0. Public domain. Boundaries are simplified for learning.")
                Link("Natural Earth", destination: URL(string: "https://www.naturalearthdata.com")!)
            }
            Section("New York City") {
                Text("Borough boundaries: NYC Department of City Planning, shore-clipped borough polygons, version 26B. These are the five official boroughs.")
                Link("NYC Open Data source", destination: URL(string: "https://data.cityofnewyork.us/d/gthc-hcne")!)
            }
            Section("NYC neighborhoods") {
                Text("37 Manhattan areas and 10 areas across the other boroughs. Bed-Stuy, DUMBO, Williamsburg, Greenpoint, and Long Island City stay separate. West Brooklyn, South & East Brooklyn, and Queens (other areas) are merged practice areas. The Bronx and Staten Island use official borough boundaries.")
                Text("Neighborhood geometry: Pediacities/Ontodia, from a pinned public mirror. Neighborhood names and inland divisions are approximate and include parks and islands. The map is clipped to official NYC DCP borough shorelines, version 26B. The Marine Park boundary was repaired before merging.")
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
