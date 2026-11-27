import BoringKit
import SwiftUI
import UIKit

@main
struct AtlasApp: App {
    @State private var progress = ProgressStore()
    // First thing at launch: this installs the crash reporter.
    init() { BoringKit.start(api: AtlasLinks.api) }
    var body: some Scene {
        WindowGroup {
            LibraryScreen()
                .updatePrompt()
                .environment(progress)
                .tint(.atlasBlue)
                .preferredColorScheme(.light)
        }
    }
}

// MARK: - Library

struct LibraryScreen: View {
    @State private var content: LearningContent?
    @State private var packs: [MapPack] = []
    @State private var loadError: String?
    @State private var launch: PracticeLaunch?
    @State private var stage = AtlasStage()
    @AppStorage("lastPractice") private var lastPractice = ""
    @AppStorage("questionTimeLimit") private var secondsAllowed = 30
    @AppStorage("practiceEntityCount") private var entityCount = 10
    @Environment(ProgressStore.self) private var progress
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 56

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Atlas")
                            .font(.system(size: titleSize, weight: .black, design: .serif))
                            .titleTape()
                            .accessibilityAddTraits(.isHeader)
                        Text(lastPractice.isEmpty ? "Borders, capitals, flags. Pick a map." : "Back for more? The map’s ready.")
                            .font(.callout.monospaced()).foregroundStyle(Color.atlasInk)
                            .labelTape()
                    }.padding(.top, 12)
                    if let loadError {
                        ContentUnavailableView("The maps got lost", systemImage: "map",
                                               description: Text("Close Atlas and open it again.\n\(loadError)"))
                            .padding(20).atlasCard()
                    } else if packs.isEmpty {
                        ProgressView("Unfolding the maps…").padding(20).atlasCard()
                            .frame(maxWidth: .infinity).padding(.top, 60)
                    } else {
                        if let next = nextUp {
                            ResumeCard(launch: next, isFirstRun: lastPractice.isEmpty,
                                       record: progress.summary(for: next.pack.id, mode: next.mode),
                                       settings: next.summary(content: content, entityCount: entityCount, secondsAllowed: secondsAllowed)) { launch = next }
                        }
                        VStack(alignment: .leading, spacing: 12) {
                            AtlasSectionHeader(title: "Maps", detail: "No signal needed")
                            MapGrid(packs: packs.filter { !$0.isNYC }, content: content, city: packs.filter(\.isNYC))
                        }
                    }
                    if loadError != nil || !packs.isEmpty { // Not while loading: it would jump down afterwards.
                        NavigationLink { SettingsScreen() } label: {
                            Label("Settings", systemImage: "gearshape").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .accessibilityIdentifier("settings")
                    }
                }
                .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 32)
                .frame(maxWidth: 700, alignment: .leading).frame(maxWidth: .infinity)
            }
            .atlasParallax()
            .atlasScreen(.home)
            .foregroundStyle(Color.atlasInk)
            .navigationTitle("Atlas") // Hidden, but names the back button.
            .toolbar(.hidden, for: .navigationBar)
            .practiceCover($launch, content: content)
            .task {
                guard packs.isEmpty, loadError == nil else { return }
                do {
                    let loaded = try await Self.loadContent()
                    content = loaded.0
                    packs = loaded.1
                } catch { loadError = error.localizedDescription }
            }
        }
        // One map lies under every screen; the stack itself is see-through.
        .background { AtlasStageBackdrop().ignoresSafeArea() }
        .environment(stage)
    }

    /// The last mode played, or Find the area on the first map for a first run.
    private var nextUp: PracticeLaunch? {
        let parts = lastPractice.split(separator: "|").map(String.init)
        if parts.count == 2, let pack = packs.first(where: { $0.id == parts[0] }),
           let mode = PracticeMode(rawValue: parts[1]), PracticeMode.available(in: pack).contains(mode) {
            return PracticeLaunch(pack: pack, mode: mode)
        }
        return packs.first.map { PracticeLaunch(pack: $0, mode: .find) }
    }

    @concurrent
    private static func loadContent() async throws -> sending (LearningContent, [MapPack]) {
        let library = try MapLibrary()
        return (try LearningContent.load(), try MapLibrary.starterIDs.map(library.load))
    }
}

private struct ResumeCard: View {
    let launch: PracticeLaunch
    let isFirstRun: Bool
    let record: PracticeRecord
    let settings: String
    let action: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                // Keyed by pack: the UIKit preview does not redraw for a new pack on its own.
                MapPreview(pack: launch.pack).id(launch.pack.id).frame(height: 140)
                    .padding(14).frame(maxWidth: .infinity)
                    .background(Color.atlasSea)
                    .mapFrame()
                    .rotationEffect(.degrees(typeSize.isAccessibilitySize ? 0 : -1.5))
                    .padding(.horizontal, 10).zIndex(1)
                    .accessibilityHidden(true)
                let layout = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(spacing: 14))
                layout {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isFirstRun ? "First stop" : "Next stop")
                            .font(.caption.monospaced().weight(.semibold)).foregroundStyle(Color.atlasInk)
                            .labelTape(.atlasYellow)
                        Text(launch.mode.title).font(.system(.title2, design: .serif, weight: .bold))
                        Text(detail).font(.subheadline).foregroundStyle(Color.atlasMuted)
                        Text(settings).font(.footnote.weight(.medium)).foregroundStyle(Color.atlasMuted)
                    }.fixedSize(horizontal: false, vertical: true)
                    if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
                    Image(systemName: "play.fill").font(.title3)
                        .foregroundStyle(.white).frame(width: 56, height: 56)
                        .atlasGlass(Circle(), fill: .atlasBlue, tint: .atlasBlue)
                        .accessibilityHidden(true)
                }
                .padding(16).padding(.top, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .atlasCard()
                .padding(.top, -24) // The framed print overlaps the paper.
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(Color.atlasInk)
            .contentShape(Rectangle())
        }
        .buttonStyle(AtlasPressStyle())
        .accessibilityIdentifier("resume-practice")
    }

    private var detail: String {
        if launch.mode == .challenge, let best = record.highScore {
            return "\(launch.pack.displayName) · High score: \(best.formatted())"
        }
        guard let accuracy = record.accuracy else { return "\(launch.pack.displayName) · \(launch.mode.instruction)" }
        return "\(launch.pack.displayName) · \(accuracy.formatted(.percent.precision(.fractionLength(0)))) on the first try"
    }
}

/// Map cards in two columns (one at large text sizes); each opens its map's setup.
private struct MapGrid: View {
    let packs: [MapPack]
    let content: LearningContent?
    var title: (MapPack) -> String? = { _ in nil }
    /// New York City's maps, shown as one card that opens the city page.
    var city: [MapPack] = []
    @Environment(ProgressStore.self) private var progress
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: typeSize >= .xxLarge ? 1 : 2),
                  alignment: .leading, spacing: 14) {
            ForEach(packs) { pack in
                NavigationLink {
                    if let content { PackScreen(pack: pack, content: content) }
                } label: {
                    LibraryMapLabel(pack: pack, record: progress.summary(for: pack.id), title: title(pack))
                }
                .buttonStyle(AtlasPressStyle())
                .accessibilityIdentifier("map-\(pack.id)")
            }
            if let boroughs = city.first {
                NavigationLink {
                    if let content { CityScreen(packs: city, content: content) }
                } label: {
                    LibraryMapLabel(pack: boroughs, record: city.map { progress.summary(for: $0.id) }.reduce(PracticeRecord(), +),
                                    title: "New York City", detail: "\(city.count) maps")
                }
                .buttonStyle(AtlasPressStyle())
                .accessibilityIdentifier("map-nyc")
            }
        }
    }
}

private struct LibraryMapLabel: View {
    let pack: MapPack
    let record: PracticeRecord
    var title: String? = nil
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MapPreview(pack: pack).frame(height: 104)
                .padding(12).frame(maxWidth: .infinity)
                .background(Color.atlasSea)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(Color.atlasInk)
                        .frame(width: 32, height: 32)
                        .atlasGlass(Circle(), tint: Color.atlasPaper.opacity(0.5)).padding(8)
                }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                // One line: "Neighborhoods" would otherwise break mid-word in a half-width card.
                Text(name).font(.system(.headline, design: .serif, weight: .bold)).lineLimit(1).minimumScaleFactor(0.75)
                Text(count).font(.subheadline).foregroundStyle(Color.atlasMuted)
            }.fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            AccuracyBar(accuracy: record.accuracy)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(Color.atlasInk)
        .atlasCard()
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name), \(count)"
            + (record.accuracy.map { ", \($0.formatted(.percent.precision(.fractionLength(0)))) correct on the first try" } ?? ""))
    }

    private var name: String { title ?? pack.displayName }
    private var count: String { detail ?? pack.countLabel }
}

/// New York City: the boroughs and the neighborhoods, as two maps one level below the home screen.
struct CityScreen: View {
    let packs: [MapPack]
    let content: LearningContent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Two maps of the city. Start with the five boroughs, then zoom in on the neighborhoods.")
                    .font(.callout.monospaced()).foregroundStyle(Color.atlasInk)
                    .labelTape()
                MapGrid(packs: packs, content: content) { $0.id == "nyc-boroughs" ? "Boroughs" : "Neighborhoods" }
            }
            .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 32)
            .frame(maxWidth: 700, alignment: .leading).frame(maxWidth: .infinity)
        }
        .atlasParallax()
        // Wider than each map's own view, so opening one zooms in on the city.
        .atlasScreen(AtlasCamera.pack("nyc").nudged(zoom: 0.6))
        .foregroundStyle(Color.atlasInk)
        .navigationTitle("New York City").navigationBarTitleDisplayMode(.large)
    }
}

struct AccuracyBar: View {
    let accuracy: Double?
    var body: some View {
        if let accuracy {
            HStack(spacing: 8) {
                Capsule().fill(Color.atlasLine).frame(height: 6)
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Capsule().fill(Color.atlasGreen).frame(width: max(6, proxy.size.width * accuracy))
                        }
                    }
                Text(accuracy, format: .percent.precision(.fractionLength(0)))
                    .font(.caption.weight(.semibold)).monospacedDigit().foregroundStyle(Color.atlasGreen)
            }.frame(minHeight: 20)
        } else {
            Text("Unexplored").font(.caption.weight(.medium)).foregroundStyle(Color.atlasMuted).frame(minHeight: 20)
        }
    }
}

// MARK: - Map setup

struct PackScreen: View {
    let pack: MapPack
    let content: LearningContent
    @State private var launch: PracticeLaunch?
    @AppStorage("questionTimeLimit") private var secondsAllowed = 30
    @AppStorage("practiceEntityCount") private var entityCount = 10
    @Environment(ProgressStore.self) private var progress
    @Environment(\.dynamicTypeSize) private var typeSize

    private var modes: [PracticeMode] { PracticeMode.available(in: pack) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                hero
                featured(.find)
                modeSection("Against the clock", modes: modes.filter { $0 == .challenge })
                modeSection("On the map", modes: modes.filter { $0.usesMap && !$0.isLocation && $0 != .find })
                modeSection("Names & facts", modes: modes.filter { !$0.usesMap })
                modeSection("Place a pin", modes: modes.filter { $0.isLocation && $0 != .challenge })
                if pack.id == "nyc-neighborhoods-focused" {
                    Text("53 areas: 38 in Manhattan and 15 across the other boroughs. The larger groups are practice areas. Neighborhood boundaries are approximate.")
                        .font(.footnote.monospaced()).foregroundStyle(Color.atlasInk).labelTape()
                }
            }
            .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 32)
            .frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .atlasParallax()
        .atlasScreen(.pack(pack.id))
        .foregroundStyle(Color.atlasInk)
        .navigationTitle(pack.displayName).navigationBarTitleDisplayMode(.large)
        .practiceCover($launch, content: content)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            MapPreview(pack: pack).frame(height: 130)
                .padding(18).frame(maxWidth: .infinity)
                .background(Color.atlasSea)
                .mapFrame()
                .padding([.horizontal, .top], 12)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 16) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 28) { stats }
                    VStack(alignment: .leading, spacing: 10) { stats }
                }
                // Side by side only when both labels fit on one line, so every pill keeps the same height.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { studyLinks }.lineLimit(1)
                    VStack(spacing: 10) { studyLinks }
                }.buttonStyle(SecondaryButtonStyle())
            }.padding(16)
        }
        .atlasCard()
    }

    @ViewBuilder private var studyLinks: some View {
        NavigationLink { StudyScreen(pack: pack, content: content) } label: {
            Label("Explore map", systemImage: "map").frame(maxWidth: .infinity)
        }.accessibilityIdentifier("study-map")
        if !content.states(in: pack).isEmpty {
            NavigationLink { ReferenceScreen(pack: pack, content: content) } label: {
                Label("Browse facts", systemImage: "book.closed").frame(maxWidth: .infinity)
            }.accessibilityIdentifier("browse-facts")
        }
    }

    @ViewBuilder private var stats: some View {
        stat("\(pack.areas.count)", pack.manifest.areaTypePlural)
        stat("\(modes.count)", "ways to play")
        if let accuracy = progress.summary(for: pack.id).accuracy {
            stat(accuracy.formatted(.percent.precision(.fractionLength(0))), "first try")
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(.title2, design: .serif, weight: .bold)).monospacedDigit()
            Text(label).font(.footnote).foregroundStyle(Color.atlasMuted)
        }.accessibilityElement(children: .combine)
    }

    private func featured(_ mode: PracticeMode) -> some View {
        let record = progress.summary(for: pack.id, mode: mode)
        return Button { launch = PracticeLaunch(pack: pack, mode: mode) } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Start here").font(.caption.monospaced().weight(.semibold)).foregroundStyle(Color.atlasInk)
                        .labelTape(.atlasYellow)
                    Text(mode.title).font(.system(.title2, design: .serif, weight: .bold))
                    Text(mode.instruction).font(.subheadline)
                    Text(PracticeLaunch(pack: pack, mode: mode).summary(content: content, entityCount: entityCount,
                                                                         secondsAllowed: secondsAllowed))
                        .font(.footnote.weight(.medium))
                    if let accuracy = record.accuracy {
                        Text("\(accuracy.formatted(.percent.precision(.fractionLength(0)))) on the first try · \(record.sessions) \(record.sessions == 1 ? "session" : "sessions")")
                            .font(.footnote.weight(.semibold)).padding(.top, 2)
                    }
                }.fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: "play.fill").font(.title3)
                    .foregroundStyle(Color.atlasBlue).frame(width: 56, height: 56)
                    .atlasGlass(Circle(), fill: .white, tint: .white)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(.white)
            .atlasCard(fill: .atlasBlue)
            .contentShape(Rectangle())
        }
        .buttonStyle(AtlasPressStyle())
        .accessibilityIdentifier("start-\(mode.rawValue)")
    }

    @ViewBuilder private func modeSection(_ title: String, modes: [PracticeMode]) -> some View {
        if !modes.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                AtlasSectionHeader(title: title)
                VStack(spacing: 0) {
                    ForEach(modes) { mode in
                        if mode != modes.first { Divider().padding(.leading, 74) }
                        modeRow(mode)
                    }
                }
                .atlasCard()
            }
        }
    }

    private func modeRow(_ mode: PracticeMode) -> some View {
        let record = progress.summary(for: pack.id, mode: mode)
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10)) : AnyLayout(HStackLayout(spacing: 14))
        return Button { launch = PracticeLaunch(pack: pack, mode: mode) } label: {
            layout {
                Image(systemName: mode.symbol).font(.body.weight(.semibold))
                    .foregroundStyle(mode.tint).frame(width: 44, height: 44)
                    .background(mode.tintFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(mode.title).font(.system(.headline, design: .serif, weight: .bold))
                    Text(mode.instruction).font(.subheadline).foregroundStyle(Color.atlasMuted)
                    if mode == .challenge, let best = record.highScore {
                        Text("High score: \(best.formatted())")
                            .font(.caption.weight(.semibold)).foregroundStyle(Color.atlasGreen)
                    } else if let accuracy = record.accuracy {
                        Text("\(accuracy.formatted(.percent.precision(.fractionLength(0)))) correct on the first try")
                            .font(.caption.weight(.semibold)).foregroundStyle(Color.atlasGreen)
                    }
                }.fixedSize(horizontal: false, vertical: true)
                if !typeSize.isAccessibilitySize {
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.atlasMuted).accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(RowPressStyle())
        .accessibilityIdentifier("start-\(mode.rawValue)")
    }
}

extension PracticeMode {
    /// Map, fact and pin modes each get one restrained accent for wayfinding.
    var tint: Color { isLocation ? .atlasAmber : usesMap ? .atlasBlue : .atlasGreen }
    var tintFill: Color { isLocation ? .atlasAmberTint : usesMap ? .atlasSea : .atlasGreenTint }
}

extension MapPack {
    var displayName: String { id == "nyc-boroughs" ? "NYC boroughs" : manifest.name }
    var isNYC: Bool { id.hasPrefix("nyc-") }
    /// "50 states", "53 areas".
    var countLabel: String { "\(areas.count) \(manifest.areaTypePlural)" }
    /// Challenge scoring: a miss this far out scores nothing, and a tenth of it counts as on target.
    var challengeRangeKM: Double {
        switch id {
        case "world-countries": 3000
        case "us-states": 1000
        case "germany-states": 300
        default: 10 // New York City
        }
    }
}

// MARK: - Shared presentation

struct PracticeLaunch: Identifiable {
    let pack: MapPack
    let mode: PracticeMode
    var id: String { pack.id + "|" + mode.rawValue }

    /// Says what one tap starts: how many questions and whether they are timed.
    func summary(content: LearningContent?, entityCount: Int, secondsAllowed: Int) -> String {
        if mode == .challenge { return "\(PracticeMode.challengeCount) places · \(PracticeMode.challengeSeconds) s each" }
        let total = content?.areas(in: pack, mode: mode).count ?? pack.areas.count
        let count = entityCount == 0 ? total : min(entityCount, total)
        return "\(count) questions · " + (secondsAllowed == 0 ? "No timer" : "\(secondsAllowed) s each")
    }
}

extension View {
    /// Practice runs full screen, like a lesson, so a stray swipe cannot end it.
    func practiceCover(_ launch: Binding<PracticeLaunch?>, content: LearningContent?) -> some View {
        modifier(PracticeCover(launch: launch, content: content))
    }

    /// Liquid Glass for controls on iOS 26; a solid `fill` with a hairline on iOS 18,
    /// under Reduce Transparency, or when `glass` is false. Never put information text on glass.
    func atlasGlass<S: InsettableShape>(_ shape: S, fill: Color = .atlasPaper, tint: Color? = nil,
                                        interactive: Bool = false, glass: Bool = true) -> some View {
        modifier(AtlasGlass(shape: shape, fill: fill, tint: tint, interactive: interactive, glass: glass))
    }
}

/// One shape for every button: text buttons and answers are 54 pt pills, icon buttons are 44 pt circles.
enum AtlasStyle {
    static let buttonHeight: CGFloat = 54
    /// A capsule at 54 pt that keeps the same 27 pt corners when large text wraps a label.
    static let buttonShape = RoundedRectangle(cornerRadius: 27)
    static let iconSize: CGFloat = 44
}

private struct AtlasGlass<S: InsettableShape>: ViewModifier {
    let shape: S, fill: Color, tint: Color?, interactive: Bool, glass: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            if glass && !reduceTransparency {
                let material = Glass.regular.tint(tint)
                content.glassEffect(interactive ? material.interactive() : material, in: shape)
            } else { solid(content) }
        } else { solid(content) }
    }
    private func solid(_ content: Content) -> some View {
        content.background(fill, in: shape).overlay(shape.strokeBorder(Color.atlasLine, lineWidth: 1))
    }
}

private struct PracticeCover: ViewModifier {
    @Binding var launch: PracticeLaunch?
    let content: LearningContent?
    @AppStorage("questionTimeLimit") private var secondsAllowed = 30
    @AppStorage("practiceEntityCount") private var entityCount = 10
    @Environment(ProgressStore.self) private var progress

    func body(content view: Content) -> some View {
        view.fullScreenCover(item: $launch) { launch in
            if let content {
                PracticeScreen(pack: launch.pack, content: content, mode: launch.mode,
                               secondsAllowed: secondsAllowed, entityCount: entityCount)
                    .environment(progress)
                    .tint(.atlasBlue)
            }
        }
    }
}

struct AtlasSectionHeader: View {
    let title: String
    var detail: String? = nil
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) { heading; Spacer(); detailText }
            VStack(alignment: .leading, spacing: 4) { heading; detailText }
        }
    }
    // Headers sit on the map, so they get their own tape.
    private var heading: some View {
        Text(title).font(.system(.title3, design: .serif, weight: .bold)).labelTape().accessibilityAddTraits(.isHeader)
    }
    @ViewBuilder private var detailText: some View {
        if let detail { Text(detail).font(.footnote.monospaced()).foregroundStyle(Color.atlasMuted).labelTape() }
    }
}

struct AtlasPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct RowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.background(configuration.isPressed ? Color.atlasInk.opacity(0.06) : Color.clear)
    }
}

/// The main action: a tinted glass pill on iOS 26, solid elsewhere and when disabled.
struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = .atlasBlue
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.body.weight(.semibold))
            .foregroundStyle(isEnabled ? Color.white : Color.atlasMuted)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: AtlasStyle.buttonHeight)
            .padding(.horizontal, 16)
            .atlasGlass(AtlasStyle.buttonShape, fill: isEnabled ? color : .atlasDisabled, tint: color,
                        interactive: true, glass: isEnabled)
            .contentShape(AtlasStyle.buttonShape)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// The same pill in paper-veiled glass. Ink labels only: blue on this glass drops to 3.9:1 over a route line.
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.body.weight(.semibold))
            .foregroundStyle(isEnabled ? Color.atlasInk : Color.atlasMuted)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .frame(minHeight: AtlasStyle.buttonHeight)
            .atlasGlass(AtlasStyle.buttonShape, fill: isEnabled ? .atlasPaper : .atlasDisabled,
                        tint: Color.atlasPaper.opacity(0.5), interactive: true, glass: isEnabled)
            .contentShape(AtlasStyle.buttonShape)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Icon-only controls: one 44 pt circle, Liquid Glass on iOS 26.
struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 17, weight: .semibold)).foregroundStyle(Color.atlasInk)
            .frame(width: AtlasStyle.iconSize, height: AtlasStyle.iconSize)
            .atlasGlass(Circle(), tint: Color.atlasPaper.opacity(0.5), interactive: true)
            .contentShape(Circle())
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

// MARK: - Practice

struct PracticeScreen: View {
    let pack: MapPack
    let content: LearningContent
    private let entityCount: Int
    private let ordered: Bool
    @State private var session: PracticeSession
    @State private var timer: QuestionTimer
    @State private var round = 0
    @State private var paused = false
    @State private var guess: MapPin?
    @State private var showAreaList = false
    @State private var showCoordinateEntry = false
    @State private var answerContentHeight: CGFloat = 0
    @State private var autoAdvanceSeconds = 3
    @State private var confirmLeave = false
    @AccessibilityFocusState private var promptFocused: Bool
    @AppStorage("lastPractice") private var lastPractice = ""
    @Environment(ProgressStore.self) private var progress
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var sizeClass

    init(pack: MapPack, content: LearningContent, mode: PracticeMode, secondsAllowed: Int, entityCount: Int) {
        self.pack = pack
        self.content = content
        let entityCount = mode == .challenge ? PracticeMode.challengeCount : entityCount
        self.entityCount = entityCount
        var ordered = false
        var seconds = mode == .challenge ? PracticeMode.challengeSeconds : secondsAllowed
        #if DEBUG
        ordered = ProcessInfo.processInfo.arguments.contains("--ui-testing")
        if ordered { seconds = ProcessInfo.processInfo.arguments.contains("--timer-test") ? 2 : 0 }
        #endif
        self.ordered = ordered
        _session = State(initialValue: Self.makeSession(content.areas(in: pack, mode: mode), mode: mode,
                                                        entityCount: entityCount, ordered: ordered, seconds: seconds))
        _timer = State(initialValue: QuestionTimer(seconds: seconds))
    }

    private static func makeSession(_ areas: [Area], mode: PracticeMode, entityCount: Int, ordered: Bool, seconds: Int) -> PracticeSession {
        PracticeSession(areas: areas, mode: mode, count: entityCount == 0 ? areas.count : entityCount,
                        ordered: ordered, secondsAllowed: seconds)
    }

    private func restart() {
        session = Self.makeSession(content.areas(in: pack, mode: session.mode), mode: session.mode,
                                   entityCount: entityCount, ordered: ordered, seconds: session.secondsAllowed)
        timer = QuestionTimer(seconds: session.secondsAllowed)
        round += 1
    }

    private var tolerance: Double {
        session.mode == .challenge ? pack.challengeRangeKM / 10 : pack.id == "us-states" ? 50 : 20
    }

    private func lockIn() {
        guard let guess, let area = session.current?.area,
              let target = content.location(area, mode: session.mode, in: pack) else { return }
        var clock = timer // The stored timer only changes once a second.
        clock.tick(now: now)
        session.submitLocation(guess, target: target, toleranceKM: tolerance,
                               rangeKM: session.mode == .challenge ? pack.challengeRangeKM : nil,
                               timeLeft: session.secondsAllowed > 0 ? clock.remaining / Double(session.secondsAllowed) : 0)
    }
    private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }
    private var answering: Bool { session.answer == nil && !paused && !session.isComplete }
    private var answerName: String {
        guard let area = session.current?.area else { return "" }
        return session.mode == .capitalLocation ? (content.state(area.id)?.capital ?? area.name) : content.answerLabel(area, mode: session.mode)
    }

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.width > geometry.size.height
            VStack(spacing: 0) {
                if let question = session.current {
                    header(question, compact: compact)
                    Group {
                        if session.mode.usesMap {
                            MapView(pack: pack, canvasHeight: nil, fullscreen: true,
                                    resetID: question.id,
                                    highlight: !session.mode.isLocation && (session.mode == .name || session.answer != nil) ? question.area.id : nil,
                                    selected: session.answer?.selected?.id,
                                    acceptsAnswers: answering && (session.mode == .find || session.mode.isLocation),
                                    guess: guess,
                                    target: session.answer != nil && session.mode.isLocation ? content.location(question.area, mode: session.mode, in: pack) : nil,
                                    onLocation: session.mode.isLocation ? { guess = $0 } : nil) { id in
                                if let area = pack.area(id) { session.submit(area) }
                            }
                            .overlay(alignment: .top) {
                                if floatsPrompt(compact) {
                                    prompt(question, compact: false, taped: true)
                                        .multilineTextAlignment(.center)
                                        .contentShape(Rectangle()) // Taps on the label never answer for an area under it.
                                        .padding(.top, 14).padding(.horizontal, 16)
                                        .animation(reduceMotion ? nil : .snappy, value: session.index)
                                        .accessibilitySortPriority(1)
                                }
                            }
                            .accessibilityElement(children: .contain) // Keeps the priority inside the map area.
                        } else {
                            factQuestion(question, height: geometry.size.height)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityHidden(paused)
                    .overlay { if paused { pausedOverlay } }
                    answerPanel(question, maximumHeight: geometry.size.height * (typeSize.isAccessibilitySize ? 0.25 : 0.40),
                                compact: compact)
                } else {
                    ScrollView { results.padding(20).frame(maxWidth: 560).frame(maxWidth: .infinity) }
                        .safeAreaInset(edge: .bottom) { resultActions }
                }
            }
        }
        .background {
            AtlasBackdrop(camera: session.isComplete
                ? AtlasCamera.pack(pack.id).nudged(longitude: 0.25, latitude: -0.15, zoom: 1.4)
                : AtlasCamera.pack(pack.id).nudged(zoom: 1.6))
                .ignoresSafeArea()
        }
        .foregroundStyle(Color.atlasInk)
        .sensoryFeedback(.selection, trigger: guess) { _, new in new != nil }
        .onAppear { lastPractice = "\(pack.id)|\(session.mode.rawValue)" }
        .onChange(of: session.isComplete) { _, complete in
            guard complete else { return }
            progress.save(session, map: pack.id)
            Usage.track("practice_finished", [
                "map": pack.id, "mode": session.mode.rawValue,
                "correct": session.firstAttemptCorrect, "total": session.primaryCount])
        }
        .onChange(of: session.current?.id) { _, _ in
            guess = nil; paused = false; autoAdvanceSeconds = 3
            timer = QuestionTimer(seconds: session.secondsAllowed)
            if scenePhase == .active { timer.resume(now: now) }
            // VoiceOver lands on the new prompt, or on the results headline.
            promptFocused = true
        }
        .onChange(of: session.answer != nil) { _, answered in
            guard answered, let answer = session.answer else { return }
            timer.pause(now: now); showAreaList = false; showCoordinateEntry = false
            if FeedbackTone(answer).outcome != .shown { // Peeking should not buzz like a mistake.
                UINotificationFeedbackGenerator().notificationOccurred(answer.correct ? .success : .warning)
            }
            UIAccessibility.post(notification: .announcement,
                                 argument: "\(answer.timedOut ? "Time is up. " : "")\(answer.correct ? "Correct. " : "The answer is ")\(answerName).")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && answering { timer.resume(now: now) }
            else { timer.pause(now: now) }
        }
        .onDisappear { timer.pause(now: now) }
        .task(id: round) {
            Usage.track("practice_started", ["map": pack.id, "mode": session.mode.rawValue])
            guard session.secondsAllowed > 0 else { return }
            if scenePhase == .active && answering { timer.resume(now: now) }
            while !Task.isCancelled && !session.isComplete {
                do { try await Task.sleep(for: .milliseconds(200)) } catch { break }
                if session.secondsAllowed > 0 && answering && scenePhase == .active {
                    var updated = timer
                    updated.tick(now: now)
                    if ceil(updated.remaining) != ceil(timer.remaining) || updated.expired { timer = updated }
                    // In the challenge a dropped pin still counts when the clock runs out.
                    if updated.expired { if session.mode == .challenge && guess != nil { lockIn() } else { session.expire() } }
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
                .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showCoordinateEntry) {
            CoordinateEntry(pack: pack) { guess = $0; showCoordinateEntry = false }
        }
    }

    // MARK: Header

    private func header(_ question: PracticeSession.Question, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Button {
                    // One stray tap must not throw away a session in progress.
                    if session.answeredCount == 0 { dismiss() } else { confirmLeave = true }
                } label: { Image(systemName: "xmark") }
                .buttonStyle(IconButtonStyle())
                .accessibilityLabel("Close").accessibilityIdentifier("leave-practice")
                .confirmationDialog("End the trip early?", isPresented: $confirmLeave, titleVisibility: .visible) {
                    Button("End trip", role: .destructive) { dismiss() }
                    Button("Keep exploring", role: .cancel) {}
                } message: {
                    Text("Answers from this session won’t be saved.")
                }
                if inlinePrompt(compact) {
                    prompt(question, compact: true).frame(maxWidth: .infinity, alignment: .leading)
                    SessionProgressBar(value: progressValue).frame(width: 140)
                } else {
                    SessionProgressBar(value: progressValue)
                }
                Text("\(session.index + 1)/\(session.questions.count)")
                    .font(.subheadline.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(Color.atlasMuted)
                    .contentTransition(.numericText())
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    .accessibilityShowsLargeContentViewer()
                    .accessibilityLabel("Question \(session.index + 1) of \(session.questions.count)")
                    .fixedSize()
                if session.secondsAllowed > 0 {
                    timerPill
                    // Kept in the layout while answered, so the progress bar does not change width.
                    Button(action: togglePause) {
                        Image(systemName: paused ? "play.fill" : "pause.fill").contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(IconButtonStyle())
                    .opacity(session.answer == nil ? 1 : 0)
                    .disabled(session.answer != nil)
                    .accessibilityHidden(session.answer != nil)
                    .accessibilityLabel(paused ? "Resume" : "Pause").accessibilityIdentifier("pause-timer")
                }
            }
            if session.mode.usesMap && !inlinePrompt(compact) && !floatsPrompt(compact) {
                prompt(question, compact: false).padding(.horizontal, 8)
            }
        }
        .padding(.horizontal, 12).padding(.bottom, 12)
        .background(Color.atlasPaper)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.atlasLine).frame(height: 1) }
        .animation(reduceMotion ? nil : .snappy, value: session.index)
    }

    private var progressValue: Double {
        session.questions.isEmpty ? 0 : Double(session.answeredCount) / Double(session.questions.count)
    }

    /// iPhone portrait only: there the top of every map is open sea at 100%, so the pill never hides a target.
    private func floatsPrompt(_ compact: Bool) -> Bool {
        session.mode.usesMap && !compact && sizeClass == .compact && !typeSize.isAccessibilitySize
    }

    /// In landscape the map prompt shares the header row, except at accessibility sizes.
    private func inlinePrompt(_ compact: Bool) -> Bool {
        compact && session.mode.usesMap && !typeSize.isAccessibilitySize
    }

    private func prompt(_ question: PracticeSession.Question, compact: Bool, taped: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(content.prompt(question.area, mode: session.mode, areaType: pack.manifest.areaType))
                .font(.system(compact ? .title3 : .title2, design: .serif, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
                .modifier(TapedIf(taped))
                .contentTransition(.opacity)
                // Large enough for 200% text, small enough to leave room for the map.
                .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($promptFocused)
                .accessibilityIdentifier("questionPrompt")
            if question.isReview { ReviewTag() }
        }
    }

    private var timerPill: some View {
        let remaining = Int(ceil(timer.remaining))
        let urgent = !paused && session.answer == nil && remaining <= 5
        return HStack(spacing: 4) {
            Image(systemName: paused ? "pause.fill" : "timer").font(.caption.weight(.bold)).accessibilityHidden(true)
            Text("\(remaining)s")
                .font(.subheadline.weight(.semibold)).monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
                .accessibilityIdentifier("question-timer")
                .accessibilityLabel(paused ? "Timer paused" : "\(remaining) seconds left")
        }
        .padding(.horizontal, 10).frame(minHeight: 32)
        .foregroundStyle(urgent ? Color.atlasRed : Color.atlasInk)
        .background(urgent ? Color.atlasRedTint : Color.atlasPaper, in: Capsule())
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .accessibilityShowsLargeContentViewer()
        .fixedSize()
        .animation(reduceMotion ? nil : .snappy, value: remaining)
    }

    private func togglePause() {
        if paused { timer.resume(now: now) } else { timer.pause(now: now) }
        paused.toggle()
    }

    private var pausedOverlay: some View {
        let card = VStack(spacing: 14) {
            Image(systemName: "pause.circle.fill").font(.system(size: 48)).foregroundStyle(Color.atlasBlue)
                .accessibilityHidden(true)
            Text("Paused").font(.title2.weight(.bold)).accessibilityAddTraits(.isHeader)
            Text("Clock’s frozen. \(session.mode.usesMap ? "The map" : "The question") will wait.").font(.subheadline).foregroundStyle(Color.atlasMuted)
                .multilineTextAlignment(.center)
            Button("Resume", action: togglePause).buttonStyle(PrimaryButtonStyle()).frame(maxWidth: 240)
                .keyboardShortcut(.defaultAction)
        }.padding(24).frame(maxWidth: .infinity)
        return ZStack {
            Rectangle().fill(.regularMaterial)
            ViewThatFits(in: .vertical) { card; ScrollView { card } }
        }.clipped()
    }

    // MARK: Fact questions

    private func factQuestion(_ question: PracticeSession.Question, height: CGFloat) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if question.isReview { ReviewTag() }
                Text(content.prompt(question.area, mode: session.mode, areaType: pack.manifest.areaType))
                    .font(.system(.title2, design: .serif, weight: .bold)).fixedSize(horizontal: false, vertical: true)
                    .labelTape()
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($promptFocused)
                    .accessibilityIdentifier("questionPrompt")
                questionClue(question, height: height)
                VStack(spacing: 10) {
                    ForEach(question.choices) { choiceButton($0, question: question) }
                }
            }
            .padding(20).frame(maxWidth: 640, alignment: .leading).frame(maxWidth: .infinity)
            .animation(feedbackAnimation, value: session.answer != nil)
        }
        .id(question.id) // Each question starts scrolled to the top.
    }

    @ViewBuilder private func questionClue(_ question: PracticeSession.Question, height: CGFloat) -> some View {
        if session.mode == .flag, let state = content.state(question.area.id), let image = LearningContent.flag(state) {
            Image(uiImage: image).resizable().scaledToFit()
                .mapFrame()
                // Small phones and landscape still show all four choices.
                .frame(maxWidth: 420, maxHeight: min(230, height * 0.2))
                .frame(maxWidth: .infinity)
                .accessibilityLabel("State flag to identify").accessibilityIdentifier("quiz-flag")
        }
        if session.mode == .nickname, let state = content.state(question.area.id) {
            VStack(alignment: .leading, spacing: 8) {
                Text("“\(state.nickname)”").font(.system(.title2, design: .serif, weight: .semibold))
                Text(state.nicknameKind).font(.footnote.weight(.medium)).foregroundStyle(Color.atlasMuted)
            }
            .padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .atlasCard()
        }
        if session.mode == .population, let place = content.place(question.area.id) {
            Text("Residents within city limits · \(place.populationDate ?? "")")
                .font(.subheadline.monospaced()).foregroundStyle(Color.atlasInk).labelTape()
        }
    }

    private func choiceButton(_ area: Area, question: PracticeSession.Question) -> some View {
        let state = ChoiceState(area: area, question: question, answer: session.answer)
        let shape = AtlasStyle.buttonShape
        return Button { session.submit(area) } label: {
            HStack(spacing: 10) {
                Text(content.answerLabel(area, mode: session.mode))
                    .font(.body.weight(.medium)).multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if let symbol = state.symbol {
                    Image(systemName: symbol).font(.title3).accessibilityHidden(true)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: AtlasStyle.buttonHeight, alignment: .leading)
            .foregroundStyle(state.foreground)
            .background(state.fill, in: shape)
            .overlay(shape.strokeBorder(state.stroke, lineWidth: state.lineWidth))
            .contentShape(shape)
        }
        .buttonStyle(AtlasPressStyle())
        // One "nope" shake on the wrong pick; offset only, so no layout change.
        .keyframeAnimator(initialValue: 0.0, trigger: state == .wrong && !reduceMotion) { content, x in
            content.offset(x: x)
        } keyframes: { _ in
            KeyframeTrack {
                LinearKeyframe(-8, duration: 0.06)
                LinearKeyframe(7, duration: 0.08)
                LinearKeyframe(-5, duration: 0.08)
                LinearKeyframe(3, duration: 0.07)
                SpringKeyframe(0, duration: 0.18, spring: .snappy)
            }
        }
        .disabled(!answering)
        .accessibilityIdentifier("choice-\(area.id)")
        .accessibilityValue(state.accessibilityValue)
    }

    private var feedbackAnimation: Animation? {
        session.answer == nil || reduceMotion ? nil : .snappy(duration: 0.3)
    }

    // MARK: Answer panel

    private func answerPanel(_ question: PracticeSession.Question, maximumHeight: CGFloat, compact: Bool) -> some View {
        let tone = session.answer.map(FeedbackTone.init)
        let showsInfo = session.answer != nil || session.mode.isLocation || session.mode == .name
        let horizontal = compact && !typeSize.isAccessibilitySize
        let layout = horizontal ? AnyLayout(HStackLayout(alignment: .center, spacing: 16)) : AnyLayout(VStackLayout(spacing: 12))
        return layout {
            if showsInfo {
                ScrollView {
                    Group {
                        if let answer = session.answer {
                            feedback(answer, question: question)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        } else if session.mode.isLocation {
                            Label(guess != nil ? "Pin dropped. Tap again to move it."
                                  : session.mode == .challenge ? "Drop a pin. Closer and faster scores more."
                                  : "Drop a pin. Anywhere within \(Int(tolerance)) km counts.",
                                  systemImage: guess == nil ? "hand.tap" : "mappin.and.ellipse")
                                .font(.subheadline).foregroundStyle(Color.atlasMuted)
                                .accessibilityIdentifier("guess-coordinate")
                        } else {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8),
                                                     count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 8) {
                                ForEach(question.choices) { choiceButton($0, question: question) }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { answerContentHeight = $0 }
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(height: min(answerContentHeight, maximumHeight))
                .frame(maxWidth: .infinity)
            }
            // Buttons keep their full height; the map gives up space instead.
            actions.fixedSize(horizontal: horizontal && showsInfo, vertical: true)
        }
        .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 8)
        .frame(maxWidth: 760).frame(maxWidth: .infinity)
        .padding(.top, TornPaper.depth)
        .background {
            TornPaper(edges: .top, seed: 3).fill(tone?.tint ?? Color.atlasPaper)
                .ignoresSafeArea(edges: [.horizontal, .bottom])
        }
        .animation(feedbackAnimation, value: session.answer != nil)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            if let answer = session.answer {
                Button { session.advance() } label: {
                    Text(session.index + 1 == session.questions.count ? "See results" : "Continue")
                }
                .buttonStyle(PrimaryButtonStyle(color: FeedbackTone(answer).color))
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("continue-session")
            } else {
                if session.mode.isLocation {
                    Button("Lock it in", action: lockIn)
                    .buttonStyle(PrimaryButtonStyle()).disabled(guess == nil || !answering)
                    .accessibilityHint("Checks how close your pin is")
                    .accessibilityIdentifier("check-location")
                }
                let stacked = typeSize >= .xxLarge
                let layout = stacked ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 10))
                layout {
                    // Quiet: the learner should try before revealing. The closest buttonStyle wins.
                    Button { session.submit(nil) } label: {
                        Label("Show answer", systemImage: "eye").frame(maxWidth: .infinity)
                    }
                    .accessibilityIdentifier("show-answer")
                    if session.mode == .find {
                        Button { showAreaList = true } label: {
                            Label("Use area list", systemImage: "list.bullet").frame(maxWidth: .infinity)
                        }.accessibilityHint("An alternative to selecting an area on the map")
                    } else if session.mode.isLocation {
                        Button { showCoordinateEntry = true } label: {
                            Label("Coordinates", systemImage: "number").frame(maxWidth: .infinity)
                        }
                        .accessibilityLabel("Enter coordinates")
                        .accessibilityHint("An alternative to placing a pin on the map")
                    }
                }
                .buttonStyle(SecondaryButtonStyle()).disabled(!answering)
                // Side by side, both pills keep one line so they stay the same height; large text stacks them instead.
                .lineLimit(stacked ? nil : 1).minimumScaleFactor(0.8)
            }
        }
    }

    /// Deterministic: a per-session offset from the first place, then one step per question.
    private var voiceSeed: Int { session.index &+ Voice.seed(session.questions.first?.area.id ?? "") }

    private func feedback(_ answer: PracticeSession.Answer, question: PracticeSession.Question) -> some View {
        let tone = FeedbackTone(answer)
        return HStack(alignment: .top, spacing: 12) {
            FeedbackGlyph(tone: tone)
            VStack(alignment: .leading, spacing: 4) {
                Text(Voice.headline(for: answer, isReview: question.isReview, streak: session.streak,
                                    toleranceKM: tolerance, seed: voiceSeed))
                    .font(.headline).foregroundStyle(tone.color)
                if session.mode.isLocation {
                    if let distance = answer.distanceKM {
                        Text("\(distance.formatted(.number.precision(.fractionLength(1)))) km from \(answerName).")
                            .font(.title3.weight(.bold))
                        if !answer.correct && distance <= tolerance * 2 {
                            Text("Just outside the \(Int(tolerance)) km circle.").foregroundStyle(Color.atlasMuted)
                        }
                    } else {
                        Text(answerName).font(.title3.weight(.bold))
                    }
                    if session.mode == .challenge {
                        Text("+\(answer.points.formatted()) points · \(session.score.formatted()) so far").fontWeight(.semibold)
                            .accessibilityIdentifier("challenge-points")
                    }
                    if answer.guess != nil { Text("A marks the answer · G marks your guess").foregroundStyle(Color.atlasMuted) }
                } else if session.mode.usesMap {
                    Text(question.area.name).font(.title3.weight(.bold))
                    if !answer.correct, let selected = answer.selected { Text("You chose \(selected.name).") }
                    if session.mode == .find && answer.correct {
                        Text("\(session.index + 1 == session.questions.count ? "Results" : "Next stop") in \(autoAdvanceSeconds)s")
                            .foregroundStyle(Color.atlasMuted)
                            .monospacedDigit().contentTransition(.numericText(countsDown: true))
                    }
                } else {
                    Text(answerName).font(.title3.weight(.bold))
                    if !answer.correct, let selected = answer.selected {
                        Text("You chose \(content.answerLabel(selected, mode: session.mode)).")
                    }
                    if session.mode == .population, let place = content.place(question.area.id) {
                        Text("\(place.populationDate ?? "") · \(place.populationDefinition ?? "City population")")
                            .font(.caption).foregroundStyle(Color.atlasMuted)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine).accessibilityIdentifier("answerFeedback")
    }

    // MARK: Results

    /// Includes the round on screen, which is saved just after the results first appear.
    private var highScore: Int {
        max(session.score, progress.summary(for: pack.id, mode: .challenge).highScore ?? 0)
    }

    private var results: some View {
        let challenge = session.mode == .challenge
        let ratio = session.primaryCount == 0 ? 0 : challenge ? Double(session.score) / Double(session.primaryCount * 1000)
            : Double(session.firstAttemptCorrect) / Double(session.primaryCount)
        let rank = ResultRank(firstTry: ratio)
        let headline = challenge && session.score > 0 && session.score == highScore ? "New high score."
            : Voice.pick(rank.headlines, Voice.seed(session.questions.first?.area.id ?? "") &+ round)
        return VStack(spacing: 28) {
            VStack(spacing: 22) {
                VStack(spacing: -10) {
                    ScoreRing(progress: ratio, value: challenge ? session.score.formatted() : nil,
                              caption: challenge ? "points" : "first try").frame(width: 172, height: 172)
                    RankStamp(rank: rank).zIndex(1)
                }
                VStack(spacing: 8) {
                    Text(headline).font(.system(.largeTitle, design: .serif, weight: .bold))
                        .accessibilityLabel("\(headline) Rank: \(rank.rawValue).")
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($promptFocused)
                    Text("A little more of the world, learned.").foregroundStyle(Color.atlasMuted)
                }.multilineTextAlignment(.center)
                Divider()
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 0) { resultStats(divided: true) }
                    VStack(spacing: 14) { resultStats(divided: false) }
                }
            }
            .padding(.vertical, 28).padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .atlasCard(torn: .bottom, seed: 5)
            .padding(.top, 12)
            if !session.missed.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    AtlasSectionHeader(title: "Worth another look")
                    VStack(spacing: 0) {
                        ForEach(session.missed) { area in
                            if area != session.missed.first { Divider().padding(.leading, 48) }
                            Label(area.name, systemImage: "arrow.uturn.backward.circle")
                                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                                .padding(.horizontal, 16)
                        }
                    }.atlasCard()
                }
            }
        }
    }

    /// Pinned under the results, so both choices stay reachable however long the missed list is.
    private var resultActions: some View {
        VStack(spacing: 10) {
            Button("Another round", action: restart)
                .buttonStyle(PrimaryButtonStyle()).keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("practice-again")
            Button { dismiss() } label: { Text("Done").frame(maxWidth: .infinity) }
                .buttonStyle(SecondaryButtonStyle()).accessibilityIdentifier("finish-practice")
        }
        .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 8)
        .frame(maxWidth: 560).frame(maxWidth: .infinity)
        .background(Color.atlasPaper.ignoresSafeArea())
        .overlay(alignment: .top) { Rectangle().fill(Color.atlasLine).frame(height: 1) }
    }

    @ViewBuilder private func resultStats(divided: Bool) -> some View {
        resultStat(session.mode == .challenge ? "On target" : "First try",
                   value: "\(session.firstAttemptCorrect) of \(session.primaryCount)", id: "firstAttemptScore")
        if session.mode == .challenge {
            if divided { Divider().frame(height: 36) }
            resultStat("High score", value: highScore.formatted(), id: "highScore")
        } else if !session.missed.isEmpty {
            if divided { Divider().frame(height: 36) }
            resultStat("On review", value: "\(session.reviewedCorrect) of \(session.missed.count)")
        }
    }

    private func resultStat(_ label: String, value: String, id: String = "") -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(.title2, design: .serif, weight: .bold)).monospacedDigit().accessibilityIdentifier(id)
            Text(label).font(.footnote).foregroundStyle(Color.atlasMuted)
        }.frame(maxWidth: .infinity)
    }
}

private struct FeedbackTone {
    /// A plain outcome that VoiceOver reads before the joke, and that tests assert on.
    enum Outcome: String { case correct = "Correct", timedOut = "Timed out", shown = "Answer shown", incorrect = "Incorrect" }
    let outcome: Outcome
    let symbol: String
    let color: Color
    let tint: Color
    init(_ answer: PracticeSession.Answer) {
        let values: (Outcome, String, Color, Color) =
            answer.correct ? (.correct, "checkmark.circle.fill", .atlasGreen, .atlasGreenTint)
            : answer.timedOut ? (.timedOut, "alarm.fill", .atlasAmber, .atlasAmberTint)
            : answer.selected == nil && answer.guess == nil ? (.shown, "eye.circle.fill", .atlasBlue, .atlasSea)
            : (.incorrect, "xmark.circle.fill", .atlasRed, .atlasRedTint)
        (outcome, symbol, color, tint) = (values.0, values.1, values.2, values.3)
    }
}

/// The outcome symbol: one bounce for right, one wiggle for wrong or late, nothing for a peek.
private struct FeedbackGlyph: View {
    let tone: FeedbackTone
    @State private var played = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Image(systemName: tone.symbol).font(.title2.weight(.semibold)).foregroundStyle(tone.color)
            .symbolEffect(.bounce, value: tone.outcome == .correct && played)
            .symbolEffect(.wiggle, value: (tone.outcome == .incorrect || tone.outcome == .timedOut) && played)
            .accessibilityLabel(tone.outcome.rawValue) // First part of the combined answerFeedback label.
            // Value-triggered effects skip the first render, so flip once after appearing.
            .onAppear { if !reduceMotion { played = true } }
    }
}

private enum ChoiceState {
    case idle, correct, wrong, dimmed
    init(area: Area, question: PracticeSession.Question, answer: PracticeSession.Answer?) {
        guard let answer else { self = .idle; return }
        self = area == question.area ? .correct : area == answer.selected ? .wrong : .dimmed
    }
    var fill: Color { self == .correct ? .atlasGreenTint : self == .wrong ? .atlasRedTint : .atlasSurface }
    var stroke: Color { self == .correct ? .atlasGreen : self == .wrong ? .atlasRed : Color.atlasInk.opacity(0.14) }
    var lineWidth: CGFloat { self == .correct || self == .wrong ? 2 : 1 }
    var foreground: Color { self == .correct ? .atlasGreen : self == .wrong ? .atlasRed : self == .dimmed ? .atlasMuted : .atlasInk }
    var symbol: String? { self == .correct ? "checkmark.circle.fill" : self == .wrong ? "xmark.circle.fill" : nil }
    var accessibilityValue: String { self == .correct ? "Correct answer" : self == .wrong ? "Your answer" : "" }
}

struct SessionProgressBar: View {
    let value: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Capsule().fill(Color.atlasSea).frame(height: 10)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule().fill(Color.atlasBlue)
                        .frame(width: value == 0 ? 0 : max(proxy.size.height, proxy.size.width * min(1, value)))
                }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.8), value: value)
            .accessibilityHidden(true)
    }
}

private struct ReviewTag: View {
    var body: some View {
        Text("Rematch").font(.caption.monospaced().weight(.semibold)).foregroundStyle(Color.atlasInk)
            .labelTape(.atlasYellow).fixedSize()
            .accessibilityLabel("Rematch: you missed this one earlier")
    }
}

/// Tape only where text sits straight on the map; elsewhere the text keeps its surface.
private struct TapedIf: ViewModifier {
    let taped: Bool
    init(_ taped: Bool) { self.taped = taped }
    @ViewBuilder func body(content: Content) -> some View {
        if taped { content.labelTape() } else { content }
    }
}

private struct ScoreRing: View {
    let progress: Double
    /// Replaces the percentage, for a points total.
    var value: String? = nil
    var caption = "first try"
    @State private var shown = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ZStack {
            Circle().stroke(Color.atlasDisabled, lineWidth: 14)
            Circle().trim(from: 0, to: shown)
                .stroke(progress == 1 ? Color.atlasGreen : Color.atlasBlue, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(value ?? progress.formatted(.percent.precision(.fractionLength(0))))
                    .font(.system(size: 42, weight: .black, design: .serif)).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.6).padding(.horizontal, 18)
                Text(caption).font(.subheadline).foregroundStyle(Color.atlasMuted)
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge) // Keeps the label inside the fixed-size ring.
        }
        .accessibilityElement(children: .combine)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 1, dampingFraction: 0.85).delay(0.15)) { shown = progress }
        }
    }
}

// MARK: - Sheets

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
                Section {
                    TextField("Latitude", text: $latitude).keyboardType(.numbersAndPunctuation)
                        .accessibilityIdentifier("latitude-input")
                    TextField("Longitude", text: $longitude).keyboardType(.numbersAndPunctuation)
                        .accessibilityIdentifier("longitude-input")
                } header: {
                    Text("Degrees · north and east are positive")
                } footer: {
                    Text("Use a minus sign for west or south. Example: 40.7, -74.0.")
                }
                Button("Place pin") {
                    guard let coordinate else { return }
                    let region = pack.id == "us-states" ?
                        (coordinate.latitude > 50 && (coordinate.longitude < -130 || coordinate.longitude > 0) ? "US-AK" :
                         coordinate.latitude < 25 && coordinate.longitude < -140 ? "US-HI" : "US-AL") : (pack.areas.first?.id ?? "")
                    onSelect(MapPin(coordinate: coordinate, regionID: region))
                }
                .buttonStyle(PrimaryButtonStyle()).disabled(coordinate == nil)
                .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                .accessibilityIdentifier("place-coordinate-pin")
            }.scrollContentBackground(.hidden).background(Color.atlasPaper)
                .navigationTitle("Enter your guess").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

// MARK: - Study

struct StudyScreen: View {
    let pack: MapPack
    let content: LearningContent
    @State private var selected: Area?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Tap an area for its name. Pinch to get closer. No quiz, promise.")
                            .font(.footnote.monospaced()).foregroundStyle(Color.atlasInk).labelTape()
                            .id("top")
                        MapView(pack: pack, canvasHeight: min(560, max(350, geometry.size.width)),
                                highlight: selected?.id, revealLabels: true) { selected = pack.area($0) }
                        VStack(alignment: .leading, spacing: 6) {
                            Text(selected?.name ?? "Pick a shape, any shape.")
                                .font(.system(.title2, design: .serif, weight: .bold)).labelTape()
                                .accessibilityIdentifier("study-selection")
                            if let selected, pack.id.hasSuffix("-states") {
                                Text("Map label \(selected.id.suffix(2))").font(.footnote.monospaced())
                                    .foregroundStyle(Color.atlasInk).labelTape()
                            }
                        }
                        if let selected, let state = content.state(selected.id) {
                            StateFactCard(state: state, torn: true)
                        }
                        AtlasSectionHeader(title: "All \(pack.manifest.areaTypePlural)", detail: "\(pack.areas.count)")
                        VStack(spacing: 0) {
                            ForEach(sortedAreas) { area in
                                if area != sortedAreas.first { Divider().padding(.leading, 16) }
                                Button {
                                    selected = area
                                    withAnimation(reduceMotion ? nil : .snappy) { proxy.scrollTo("top", anchor: .top) }
                                } label: {
                                    HStack {
                                        Text(area.name)
                                        Spacer()
                                        if pack.id.hasSuffix("-states") {
                                            Text(String(area.id.suffix(2))).font(.subheadline.monospaced()).foregroundStyle(Color.atlasMuted)
                                        }
                                        if selected == area {
                                            Image(systemName: "checkmark").font(.subheadline.weight(.bold)).foregroundStyle(Color.atlasBlue)
                                        }
                                    }
                                    .padding(.horizontal, 16).frame(minHeight: 50).contentShape(Rectangle())
                                }
                                .buttonStyle(RowPressStyle())
                                .accessibilityAddTraits(selected == area ? .isSelected : [])
                            }
                        }
                        .atlasCard()
                    }
                    .padding(20).frame(maxWidth: 860).frame(maxWidth: .infinity)
                    .animation(reduceMotion ? nil : .snappy, value: selected)
                }
                .atlasParallax()
            }
        }
        .atlasScreen(AtlasCamera.pack(pack.id).nudged(longitude: 0.18, latitude: -0.12, zoom: 1.3))
        .foregroundStyle(Color.atlasInk).navigationTitle("Explore the map").navigationBarTitleDisplayMode(.inline)
    }
    private var sortedAreas: [Area] { pack.areas.sorted { $0.name < $1.name } }
}

struct AreaList: View {
    let pack: MapPack
    let title: String
    let onSelect: (Area) -> Void
    @State private var search = ""
    @Environment(\.dismiss) private var dismiss
    private var matchingAreas: [Area] {
        pack.areas.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }.sorted { $0.name < $1.name }
    }
    var body: some View {
        NavigationStack {
            List(matchingAreas) { area in
                Button { onSelect(area) } label: {
                    Text(area.name).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                }
                .foregroundStyle(Color.atlasInk)
                .accessibilityIdentifier("area-\(area.id)")
            }.overlay {
                if matchingAreas.isEmpty {
                    ContentUnavailableView("Not on this map", systemImage: "mappin.slash",
                                           description: Text("Nothing matches “\(search)”."))
                        .accessibilityIdentifier("area-no-results")
                }
            }.scrollContentBackground(.hidden).background(Color.atlasPaper)
                .searchable(text: $search, prompt: "Search areas").navigationTitle(title).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

/// The public website at atlas-practice.app: GitHub Pages, built from website/ in this repository.
enum AtlasLinks {
    static let site = URL(string: "https://atlas-practice.app/")!
    static let support = site.appending(path: "support/")
    static let privacy = site.appending(path: "privacy/")
    /// The Worker that receives crash reports, usage events and feedback (BoringKit).
    static let api = URL(string: "https://api.atlas-practice.app")!
}

/// Usage events, unless the user switched them off in Settings. Crash reports and feedback don't pass through here.
enum Usage {
    static let key = "shareUsageData"
    @MainActor static func track(_ name: String, _ props: [String: Any]) {
        guard UserDefaults.standard.object(forKey: key) as? Bool ?? true else { return }
        Aptabase.shared.trackEvent(name, with: props)
    }
}

/// Round settings for every map, how progress is kept, help, and where the maps come from.
struct SettingsScreen: View {
    @AppStorage("questionTimeLimit") private var secondsAllowed = 30
    @AppStorage("practiceEntityCount") private var entityCount = 10
    @AppStorage("lastPractice") private var lastPractice = ""
    @Environment(ProgressStore.self) private var progress
    @State private var confirmingReset = false
    @State private var showingFeedback = false
    @AppStorage(Usage.key) private var shareUsage = true

    var body: some View {
        List {
            AtlasListSection("Practice rounds") {
                settingRow("Questions", systemImage: "list.number") {
                    Picker("Questions per session", selection: $entityCount) {
                        Text("10").tag(10)
                        Text("25").tag(25)
                        Text("All").tag(0)
                    }.pickerStyle(.segmented).accessibilityIdentifier("session-length")
                }
                settingRow("Timer", systemImage: "timer") {
                    Picker("Time per question", selection: $secondsAllowed) {
                        Text("Off").tag(0)
                        Text("30 s").tag(30)
                        Text("60 s").tag(60)
                    }.pickerStyle(.segmented).accessibilityIdentifier("timer-setting")
                }
                Text("Applies to every map. Miss one and it comes back once for a rematch.")
                    .font(.footnote).foregroundStyle(Color.atlasMuted)
            }
            AtlasListSection("Your progress") {
                Text("Progress stays on this device. No account needed.")
                Button("Reset progress", role: .destructive) { confirmingReset = true }
                    .foregroundStyle(Color.atlasRed) // The screen's ink style would otherwise hide the role.
                    .accessibilityIdentifier("reset-progress")
            }
            AtlasListSection("Privacy") {
                Toggle("Share usage data", isOn: $shareUsage).accessibilityIdentifier("share-usage-data")
                Text("Which maps and modes you practice and how rounds end. Not linked to you. Crash reports are always sent.")
                    .font(.footnote).foregroundStyle(Color.atlasMuted)
            }
            AtlasListSection("Help") {
                Link(destination: AtlasLinks.support) { Label("Help and support", systemImage: "questionmark.circle") }
                Link(destination: AtlasLinks.privacy) { Label("Privacy policy", systemImage: "hand.raised") }
                Button { showingFeedback = true } label: { Label("Send feedback", systemImage: "envelope") }
                    .accessibilityIdentifier("send-feedback")
            }
            AtlasListSection("About") {
                NavigationLink { SourcesScreen() } label: { Label("Map sources and credits", systemImage: "info.circle") }
                LabeledContent("Version", value: Self.version)
            }
        }.scrollContentBackground(.hidden)
            .confirmationDialog("Reset all progress?", isPresented: $confirmingReset, titleVisibility: .visible) {
                Button("Reset progress", role: .destructive) { progress.reset(); lastPractice = "" }
            } message: {
                Text("Scores for every map and mode are deleted from this device. This can’t be undone.")
            }
            .sheet(isPresented: $showingFeedback) { FeedbackView() }
            .atlasParallax()
            .atlasScreen(.settings)
            .foregroundStyle(Color.atlasInk)
            .navigationTitle("Settings").navigationBarTitleDisplayMode(.large)
    }

    private func settingRow<Control: View>(_ title: String, systemImage: String,
                                           @ViewBuilder control: () -> Control) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                Label(title, systemImage: systemImage).font(.subheadline.weight(.semibold))
                Spacer(minLength: 8)
                control().frame(width: 160)
            }
            VStack(alignment: .leading, spacing: 8) {
                Label(title, systemImage: systemImage).font(.subheadline.weight(.semibold))
                control()
            }
        }
    }

    /// "1.0 (1)": marketing version and build.
    private static var version: String {
        let info = Bundle.main.infoDictionary
        return "\(info?["CFBundleShortVersionString"] as? String ?? "?") (\(info?["CFBundleVersion"] as? String ?? "?"))"
    }
}

struct SourcesScreen: View {
    var body: some View {
        List {
            AtlasListSection("United States, Germany, and the world") {
                Text("Boundaries: Natural Earth, Admin 1 states and provinces, version 5.1.1. State maps exclude mapped lakes using Natural Earth Lakes, version 5.0.0. Public domain. Boundaries are simplified for learning.")
                Text("World map, the map behind every screen, and the app icon: Natural Earth Admin 0 countries, 1:50m, version 5.1.1, with 1:50m lakes. Public domain. The World map asks for the 193 UN member states, the two UN observer states, Kosovo and Taiwan.")
                Link("Natural Earth", destination: URL(string: "https://www.naturalearthdata.com")!)
            }
            AtlasListSection("New York City") {
                Text("Borough boundaries: NYC Department of City Planning, shore-clipped borough polygons, version 26B. These are the five official boroughs.")
                Link("NYC Open Data source", destination: URL(string: "https://data.cityofnewyork.us/d/gthc-hcne")!)
            }
            AtlasListSection("NYC neighborhoods") {
                Text("38 Manhattan areas and 15 areas across the other boroughs. Seaport is hand-drawn out of the Financial District: Pearl Street, John Street, the Brooklyn Bridge, and the East River, approximately. Bed-Stuy, DUMBO, Williamsburg, Greenpoint, Park Slope, Prospect Heights, Downtown Brooklyn, Crown Heights, Prospect Park, and Long Island City stay separate. West Brooklyn, South & East Brooklyn, and Queens (other areas) are merged practice areas. The Bronx and Staten Island use official borough boundaries.")
                Text("Neighborhood geometry: Pediacities/Ontodia, from a pinned public mirror. Neighborhood names and inland divisions are approximate and include parks and islands. The map is clipped to official NYC DCP borough shorelines, version 26B. The Marine Park boundary was repaired before merging.")
                Text("The datHere catalog declares the Open Data Commons Attribution License. Its download could not be compared with the mirror, so exact source equivalence remains unconfirmed.")
                Text("Contains information from NYC Neighborhoods (Pediacities/Ontodia, via datHere), made available under the Open Data Commons Attribution License.")
                Link("Neighborhood catalog and attribution", destination: URL(string: "https://data.dathere.com/dataset/nyc-neighborhoods")!)
                Link("Open Data Commons Attribution License", destination: URL(string: "https://opendatacommons.org/licenses/by/1-0/")!)
            }
            AtlasListSection("Facts, flags, cities, and sights") {
                Text("State capitals, US state nicknames, and geographic points: Wikidata, CC0. Flags: Wikimedia Commons, with file-specific credits in Browse facts. German state names and slogans link to their own sources there.")
                Text("US city populations: U.S. Census Bureau, Vintage 2025 estimates for July 1, 2025.")
                Text("German city populations: Statistisches Bundesamt (Destatis), as of December 31, 2024; the ten largest were selected by Atlas. Datenlizenz Deutschland – Namensnennung – Version 2.0.")
                Text("The figures use city or municipal boundaries, not metro areas.")
                Text("Beat the clock: on the World map, 148 major cities from Natural Earth populated places, version 5.1.2, public domain. In New York City, 56 curated sights with coordinates from Wikidata, CC0. On the US and German maps, the cities and landmarks listed here.")
                Text("Landmarks are a curated collection of 50 US and 20 German sights. Large parks use the source reference point. Each detail page links to its source.")
                Link("US Census population tables", destination: URL(string: "https://www.census.gov/data/tables/time-series/demo/popest/2020s-total-cities-and-towns.html")!)
                Link("Destatis city populations", destination: URL(string: "https://service.destatis.de/DE/barchart_race/BarChartRace500k_Berlin_1955-2024.html")!)
                Link("Datenlizenz Deutschland – Namensnennung – Version 2.0", destination: URL(string: "https://www.govdata.de/dl-de/by-2-0")!)
            }
            AtlasListSection("Map layout") {
                Text("Alaska and Hawaii appear in separate insets at different scales. The map uses geographic coordinates. It is intended for learning, not navigation.")
            }
            AtlasListSection("Software") {
                Text("Crash reports, usage figures and feedback use three open-source packages under the MIT License: BoringKit, KSCrash (Copyright (c) 2012 Karl Stenerud) and aptabase-swift (Copyright (c) 2023 Sumbit Labs Ltd.).")
                Link("BoringKit", destination: URL(string: "https://github.com/jkrenge/boring-ass-app-kit")!)
                Link("KSCrash", destination: URL(string: "https://github.com/kstenerud/KSCrash")!)
                Link("aptabase-swift", destination: URL(string: "https://github.com/aptabase/aptabase-swift")!)
            }
            AtlasListSection("Your progress") {
                Text("Practice results are saved only on this device. Scores are kept for each mode and combine all timer settings. First attempts and review answers are counted separately.")
            }
        }.scrollContentBackground(.hidden)
            .atlasParallax()
            .atlasScreen(.sources)
            .buttonStyle(SecondaryButtonStyle())
            .navigationTitle("Sources and credits").navigationBarTitleDisplayMode(.inline)
    }
}

/// A list section on the map: paper rows and a taped header.
struct AtlasListSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    var body: some View {
        Section {
            content.listRowBackground(Color.atlasPaper)
        } header: {
            Text(title).font(.footnote.monospaced().weight(.semibold)).foregroundStyle(Color.atlasInk)
                .textCase(nil).labelTape()
        }
    }
}
