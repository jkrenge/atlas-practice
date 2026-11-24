import SwiftUI

// Paper, tape and ink: the cut-and-paste pieces that sit on the atlas.
// Information lives on opaque paper or tape; glass is only for controls.

/// Paper with torn top and/or bottom edges. A pure function of size and seed, so the tear never jitters.
struct TornPaper: Shape {
    var edges: Edge.Set = []
    var seed = 1
    static let tooth: CGFloat = 9
    static let depth: CGFloat = 3

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        edge(&path, y: rect.minY, from: rect.minX, to: rect.maxX, inward: 1, torn: edges.contains(.top))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        edge(&path, y: rect.maxY, from: rect.maxX, to: rect.minX, inward: -1, torn: edges.contains(.bottom))
        path.closeSubpath()
        return path
    }

    private func edge(_ path: inout Path, y: CGFloat, from x0: CGFloat, to x1: CGFloat, inward: CGFloat, torn: Bool) {
        let salt = inward > 0 ? 0 : 2
        let count = torn ? max(4, Int(abs(x1 - x0) / Self.tooth)) : 1
        for i in 1..<count {
            let t = CGFloat(i) / CGFloat(count)
            let swell = 0.5 + 0.5 * sin(t * 11 + CGFloat(seed)) // A slow wave, so it never reads as a saw.
            let bite = Self.depth * (0.6 * noise(i, salt) + 0.4 * swell)
            let x = x0 + (x1 - x0) * t + (noise(i, salt + 1) - 0.5) * Self.tooth * 0.4
            path.addLine(to: CGPoint(x: x, y: y + inward * bite))
        }
        path.addLine(to: CGPoint(x: x1, y: y))
    }

    /// SplitMix64 to 0..<1: deterministic, no Random.
    private func noise(_ i: Int, _ salt: Int) -> CGFloat {
        var z = UInt64(truncatingIfNeeded: seed &* 1_000_003 &+ i &* 31 &+ salt &* 7_919) &+ 0x9E37_79B9_7F4A_7C15
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return CGFloat((z ^ (z >> 31)) >> 11) / 9_007_199_254_740_992 // 2^53
    }
}

extension View {
    /// Information sits on paper: opaque, square, with a hard collage shadow. `torn`: one edge per screen at most.
    func atlasCard(torn edges: Edge.Set = [], seed: Int = 1, fill: Color = .atlasPaper) -> some View {
        modifier(PaperCard(shape: TornPaper(edges: edges, seed: seed), fill: fill))
    }

    /// Text that sits on the map gets its own solid block per line: the explainer-video "color padding".
    func labelTape(_ fill: Color = .atlasSurface) -> some View { modifier(LabelTape(fill: fill, tilt: .zero, wipes: false)) }

    /// The one yellow title strip per screen: slightly tilted, wiped in once.
    func titleTape() -> some View { modifier(LabelTape(fill: .atlasYellow, tilt: .degrees(-2), wipes: true)) }

    /// The exhibit frame: a thick yellow mat around the map or flag being studied.
    func mapFrame() -> some View {
        overlay(Rectangle().strokeBorder(Color.atlasInk.opacity(0.18), lineWidth: 1))
            .padding(10)
            .background {
                Rectangle().fill(Color.atlasInk.opacity(0.14)).offset(x: 2, y: 3) // Hard shadow, no blur.
                Rectangle().fill(Color.atlasYellow)
            }
    }
}

private struct PaperCard: ViewModifier {
    let shape: TornPaper
    let fill: Color
    @Environment(\.colorSchemeContrast) private var contrast
    func body(content: Content) -> some View {
        // A hard offset copy instead of a blurred shadow: blur costs measurable CPU while scrolling.
        content
            .background {
                shape.fill(Color.atlasInk.opacity(0.14)).offset(x: 2, y: 3)
                shape.fill(fill)
            }
            .overlay(shape.stroke(Color.atlasInk.opacity(contrast == .increased ? 0.45 : 0.12), lineWidth: 1))
    }
}

/// Draws one solid block behind the laid-out text, then the words on top. Wrapped labels get a
/// single box, so no map shows through between the words (and contrast holds everywhere in the frame).
struct TapeRenderer: TextRenderer {
    var fill: Color
    var reveal: Double = 1 // 0 to 1: the blocks wipe in from the leading edge, then the words fade in.
    var animatableData: Double {
        get { reveal }
        set { reveal = newValue }
    }
    var displayPadding: EdgeInsets { EdgeInsets(top: 3, leading: 6, bottom: 3, trailing: 6) }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        var block = layout.reduce(CGRect.null) { $0.union($1.typographicBounds.rect) }.insetBy(dx: -6, dy: -3)
        guard !block.isNull else { return }
        block.size.width *= min(1, reveal / 0.6)
        context.fill(Path(block), with: .color(fill))
        context.opacity = min(1, max(0, (reveal - 0.4) / 0.6))
        for line in layout { context.draw(line) }
    }
}

private struct LabelTape: ViewModifier {
    let fill: Color
    let tilt: Angle
    let wipes: Bool
    @State private var reveal: Double
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(fill: Color, tilt: Angle, wipes: Bool) {
        self.fill = fill
        self.tilt = tilt
        self.wipes = wipes
        _reveal = State(initialValue: wipes ? 0 : 1)
    }

    func body(content: Content) -> some View {
        content
            .textRenderer(TapeRenderer(fill: fill, reveal: reveal))
            .lineSpacing(2)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .rotationEffect(typeSize.isAccessibilitySize ? .zero : tilt)
            .onAppear {
                guard reveal < 1 else { return }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.45).delay(0.15)) { reveal = 1 }
            }
    }
}

/// The results rank, inked on like a rubber stamp. VoiceOver already hears the rank in the headline.
struct RankStamp: View {
    let rank: ResultRank
    @State private var landed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 6)
        VStack(spacing: 1) {
            Text("First-try rank").font(.caption2.monospaced().weight(.semibold))
            Text(rank.rawValue.uppercased())
                .font(.system(.title2, design: .serif, weight: .black)).tracking(2)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .overlay(shape.inset(by: 4).strokeBorder(lineWidth: 1))
        .overlay(shape.strokeBorder(lineWidth: 2.5))
        .foregroundStyle(Color.atlasRed)
        .opacity(contrast == .increased ? 1 : 0.9)
        .rotationEffect(.degrees(typeSize.isAccessibilitySize ? 0 : -8))
        .scaleEffect(landed ? 1 : 1.4)
        .opacity(landed ? 1 : 0)
        .sensoryFeedback(.impact(weight: .heavy, intensity: 0.7), trigger: landed)
        .accessibilityHidden(true)
        .onAppear { // Lands just after the score ring fills.
            withAnimation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.55).delay(1.1)) { landed = true }
        }
    }
}
