import SwiftUI
import UIKit

// The shared backdrop: one big world map in school-atlas style, lying under the whole app.
// Each screen points the camera somewhere else, and the map glides there.

/// Where the backdrop looks: a point on the world and how many degrees of longitude fit the width.
struct AtlasCamera: Equatable {
    var longitude: Double
    var latitude: Double
    var span: Double

    static let home = AtlasCamera(longitude: -7, latitude: 33, span: 38)
    static let sources = AtlasCamera(longitude: -1, latitude: 50, span: 10)
    static let settings = AtlasCamera(longitude: -20, latitude: 42, span: 16)

    static func pack(_ id: String) -> AtlasCamera {
        switch id {
        case "us-states": AtlasCamera(longitude: -97, latitude: 38, span: 32)
        case "germany-states": AtlasCamera(longitude: 10.5, latitude: 51, span: 11)
        default: AtlasCamera(longitude: -73.9, latitude: 40.7, span: 4.5)
        }
    }

    /// A nearby view for a screen one level deeper, so pushing feels like moving across the table.
    func nudged(longitude dx: Double = 0, latitude dy: Double = 0, zoom: Double = 1) -> AtlasCamera {
        AtlasCamera(longitude: longitude + dx * span, latitude: latitude + dy * span, span: span / zoom)
    }
}

/// The camera the root backdrop follows, set by whichever screen is showing.
@MainActor
@Observable
final class AtlasStage {
    var camera = AtlasCamera.home
    /// Scroll offset of the current screen, for a slow parallax drift.
    var scroll: CGFloat = 0
}

extension View {
    /// Points the shared backdrop at `camera` while this screen is showing.
    func atlasCamera(_ camera: AtlasCamera) -> some View { modifier(AtlasCameraModifier(camera: camera)) }
    /// A screen that sits on the shared map: see-through, with the camera on `camera`.
    func atlasScreen(_ camera: AtlasCamera) -> some View {
        atlasCamera(camera).containerBackground(.clear, for: .navigation)
    }
    /// Lets the backdrop drift a little as this scroll view moves.
    func atlasParallax() -> some View { modifier(AtlasParallaxModifier()) }
}

private struct AtlasCameraModifier: ViewModifier {
    let camera: AtlasCamera
    @Environment(AtlasStage.self) private var stage
    func body(content: Content) -> some View {
        content.onAppear { stage.camera = camera; stage.scroll = 0 }
    }
}

private struct AtlasParallaxModifier: ViewModifier {
    @Environment(AtlasStage.self) private var stage
    func body(content: Content) -> some View {
        content.onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { _, offset in
            stage.scroll = offset
        }
    }
}

/// The root backdrop, which follows the stage.
struct AtlasStageBackdrop: View {
    @Environment(AtlasStage.self) private var stage
    var body: some View { AtlasBackdrop(camera: stage.camera, scroll: stage.scroll) }
}

struct AtlasBackdrop: UIViewRepresentable {
    var camera: AtlasCamera
    var scroll: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeUIView(context: Context) -> AtlasBackdropView { AtlasBackdropView() }
    func updateUIView(_ view: AtlasBackdropView, context: Context) {
        view.update(camera: camera, scroll: scroll, animated: !reduceMotion)
    }
}

final class AtlasBackdropView: UIView {
    private let content = UIView()
    private var camera: AtlasCamera?
    private var scroll: CGFloat = 0

    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        accessibilityElementsHidden = true
        clipsToBounds = true
        backgroundColor = UIColor(AtlasInk.water)
        content.bounds = CGRect(origin: .zero, size: AtlasWorld.size)
        addSubview(content)
        Task { @MainActor [weak self] in
            guard let world = try? await AtlasWorld.shared.value, let self else { return }
            let tiles = AtlasTileLayer(world: world, scale: self.traitCollection.displayScale)
            tiles.opacity = 0
            self.content.layer.addSublayer(tiles)
            tiles.setNeedsDisplay()
            // Fade the drawing in over the plain water, like ink settling on paper.
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0; fade.toValue = 1; fade.duration = 0.35
            tiles.add(fade, forKey: "fade")
            tiles.opacity = 1
        }
    }
    required init?(coder: NSCoder) { fatalError("Use init()") }

    override func layoutSubviews() {
        super.layoutSubviews()
        place(animated: false)
    }

    func update(camera: AtlasCamera, scroll: CGFloat, animated: Bool) {
        let moved = camera != self.camera
        let first = self.camera == nil
        self.camera = camera
        self.scroll = scroll
        place(animated: moved && !first && animated)
    }

    private func place(animated: Bool) {
        guard let camera, bounds.width > 0, bounds.height > 0 else { return }
        let size = AtlasWorld.size
        // Never zoom out past the edge of the paper.
        let scale = max(bounds.width / (camera.span * AtlasWorld.pointsPerDegree),
                        bounds.height / size.height, bounds.width / size.width)
        var center = AtlasWorld.point(longitude: camera.longitude, latitude: camera.latitude)
        center.y += scroll * 0.3 / scale // The map drifts slower than the page.
        let half = CGSize(width: bounds.width / 2 / scale, height: bounds.height / 2 / scale)
        center.x = min(max(center.x, half.width), size.width - half.width)
        center.y = min(max(center.y, half.height), size.height - half.height)
        let apply = {
            self.content.transform = CGAffineTransform(scaleX: scale, y: scale)
            self.content.center = CGPoint(x: self.bounds.midX - (center.x - size.width / 2) * scale,
                                          y: self.bounds.midY - (center.y - size.height / 2) * scale)
        }
        if animated {
            UIView.animate(withDuration: 0.9, delay: 0, usingSpringWithDamping: 0.92, initialSpringVelocity: 0,
                           options: [.allowUserInteraction, .beginFromCurrentState], animations: apply)
        } else {
            UIView.performWithoutAnimation(apply)
        }
    }
}

/// School-atlas colors. Muted on purpose: the map is scenery, the cards and buttons are the stage.
enum AtlasInk {
    static let water = Color(red: 0.74, green: 0.87, blue: 0.85)
    static let waterLine = Color(red: 0.49, green: 0.70, blue: 0.70)
    static let land = Color(red: 0.95, green: 0.91, blue: 0.80)
    static let border = Color(red: 0.62, green: 0.52, blue: 0.40)
    static let forest = Color(red: 0.45, green: 0.58, blue: 0.40)
    static let highland = Color(red: 0.78, green: 0.64, blue: 0.45)
    static let contour = Color(red: 0.60, green: 0.47, blue: 0.32)
    static let graticule = Color(red: 0.30, green: 0.48, blue: 0.53)
    static let oceanLabel = Color(red: 0.26, green: 0.47, blue: 0.50)
    static let route = Color(red: 0.722, green: 0.227, blue: 0.180) // #B83A2E, also wrong picks in the game
}

/// Prepared world geometry in map points: equirectangular, 84°N to 80°S.
final class AtlasWorld: @unchecked Sendable {
    // Immutable after init, so tiles can draw it on background threads.
    static let pointsPerDegree: CGFloat = 8
    static let north = 84.0, south = -80.0
    static let size = CGSize(width: 360 * pointsPerDegree, height: (north - south) * pointsPerDegree)
    static func point(longitude: Double, latitude: Double) -> CGPoint {
        CGPoint(x: (longitude + 180) * pointsPerDegree, y: (north - latitude) * pointsPerDegree)
    }

    static let shared = Task.detached(priority: .userInitiated) { try AtlasWorld() }

    struct Country { let path: CGPath; let bounds: CGRect }
    struct Bucket { let rect: CGRect; let path: CGPath }

    let countries: [Country]
    let contours: [Bucket]
    /// Flat tint areas, as on a printed atlas: forest, then two steps of highland.
    let tints: [(buckets: [Bucket], color: CGColor)]

    init(bundle: Bundle = .main) throws {
        guard let url = bundle.resourceURL?.appendingPathComponent("maps/world-countries/areas-lowres.geojson") else {
            throw MapLoadError.invalid("The world map is missing.")
        }
        let features = try JSONDecoder().decode(FeatureCollection.self, from: Data(contentsOf: url)).features
        countries = features.map { feature in
            let path = CGMutablePath()
            for polygon in feature.geometry.polygons {
                for ring in polygon {
                    path.addLines(between: ring.map { Self.point(longitude: $0.longitude, latitude: $0.latitude) })
                    path.closeSubpath()
                }
            }
            return Country(path: path, bounds: path.boundingBoxOfPath)
        }
        let field = Terrain()
        contours = field.contours()
        tints = [
            (field.bands(above: 0.35) { field.highland(column: $0, row: $1) },
             UIColor(AtlasInk.highland).withAlphaComponent(0.28).cgColor),
            (field.bands(above: 0.75) { field.highland(column: $0, row: $1) },
             UIColor(AtlasInk.highland).withAlphaComponent(0.3).cgColor),
            (field.bands(above: 0.5) { field.forest(column: $0, row: $1) },
             UIColor(AtlasInk.forest).withAlphaComponent(0.5).cgColor),
        ]
    }
}

/// Invented terrain: smooth noise plus a few real mountain ridges, so the hills fall roughly where they should.
private struct Terrain {
    static let step = 0.5 // degrees per grid cell
    let columns = Int(360 / Terrain.step)
    let rows = Int((AtlasWorld.north - AtlasWorld.south) / Terrain.step)
    /// Elevation at every grid corner, computed once and shared by the contours and both washes.
    let grid: [Double]

    init() {
        var grid = [Double](repeating: 0, count: (columns + 1) * (rows + 1))
        for row in 0...rows {
            for column in 0...columns {
                grid[row * (columns + 1) + column] = Self.elevation(-180 + Double(column) * Self.step,
                                                                    AtlasWorld.north - Double(row) * Self.step)
            }
        }
        self.grid = grid
    }
    private func height(_ column: Int, _ row: Int) -> Double { grid[row * (columns + 1) + column] }

    private static let ridges: [[(Double, Double)]] = [
        [(-79, 8), (-75, -10), (-70, -25), (-71, -50)],     // Andes
        [(-135, 62), (-118, 50), (-110, 42), (-106, 33)],   // Rockies
        [(68, 37), (80, 32), (92, 28), (98, 27)],           // Himalaya
        [(5, 45), (11, 47), (16, 47)],                      // Alps
        [(38, 12), (37, 0), (35, -10)],                     // East Africa
        [(42, 43), (50, 40)],                               // Caucasus
        [(-8, 32), (2, 35)],                                // Atlas
        [(58, 52), (60, 65)],                               // Urals
        [(146, -20), (150, -35)],                           // Great Dividing Range
    ]

    private static func elevation(_ longitude: Double, _ latitude: Double) -> Double {
        var value = 0.35 + 0.35 * fractal(longitude / 14, latitude / 14, seed: 11)
        for ridge in Self.ridges {
            let distance = Self.distance((longitude, latitude), to: ridge)
            value += 0.45 * exp(-(distance * distance) / 18)
        }
        return value
    }

    func forest(column: Int, row: Int) -> Double {
        let longitude = -180 + Double(column) * Self.step, latitude = AtlasWorld.north - Double(row) * Self.step
        let band: Double = switch abs(latitude) {
        case ..<11: 0.28
        case ..<16: 0.08
        case ..<33: -0.4
        case ..<45: 0.02
        case ..<62: 0.22
        case ..<68: 0.05
        default: -0.6
        }
        let value = 0.45 + 0.45 * Self.fractal(longitude / 9, latitude / 9, seed: 47) + band
        return smoothstep(0.62, 0.78, value) * (1 - smoothstep(0.72, 0.9, height(column, row)))
    }

    func highland(column: Int, row: Int) -> Double { smoothstep(0.66, 0.92, height(column, row)) }

    /// Filled areas where `value` is above `level`, by marching squares: each cell contributes the
    /// part of its square on the high side, with edges interpolated, so the outlines are smooth at any zoom.
    /// Cells are grouped into 10° buckets; every polygon winds the same way, so one fill has no seams.
    func bands(above level: Double, _ value: (Int, Int) -> Double) -> [AtlasWorld.Bucket] {
        var values = [Double](repeating: 0, count: (columns + 1) * (rows + 1))
        for row in 0...rows { for column in 0...columns { values[row * (columns + 1) + column] = value(column, row) } }
        let cellsPerBucket = 20
        let unit = Self.step * AtlasWorld.pointsPerDegree
        var paths: [Int: CGMutablePath] = [:]
        for row in 0..<rows {
            for column in 0..<columns {
                let corners = [(column, row), (column + 1, row), (column + 1, row + 1), (column, row + 1)]
                let v = corners.map { values[$0.1 * (columns + 1) + $0.0] }
                guard v.contains(where: { $0 >= level }) else { continue }
                let p = corners.map { CGPoint(x: CGFloat($0.0) * unit, y: CGFloat($0.1) * unit) }
                var polygon: [CGPoint] = []
                for k in 0..<4 {
                    let n = (k + 1) % 4
                    if v[k] >= level { polygon.append(p[k]) }
                    if (v[k] >= level) != (v[n] >= level) {
                        let t = CGFloat((level - v[k]) / (v[n] - v[k]))
                        polygon.append(CGPoint(x: p[k].x + (p[n].x - p[k].x) * t, y: p[k].y + (p[n].y - p[k].y) * t))
                    }
                }
                guard polygon.count >= 3 else { continue }
                let key = (row / cellsPerBucket) * 1000 + column / cellsPerBucket
                let path = paths[key] ?? CGMutablePath()
                path.addLines(between: polygon)
                path.closeSubpath()
                paths[key] = path
            }
        }
        let side = CGFloat(cellsPerBucket) * unit
        return paths.map { key, path in
            AtlasWorld.Bucket(rect: CGRect(x: CGFloat(key % 1000) * side, y: CGFloat(key / 1000) * side,
                                           width: side, height: side), path: path)
        }
    }

    /// Height lines by marching squares, grouped into 10° buckets so a tile only strokes what it shows.
    func contours() -> [AtlasWorld.Bucket] {
        let levels = [0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
        let cellsPerBucket = 20
        var paths: [Int: CGMutablePath] = [:]
        let unit = Self.step * AtlasWorld.pointsPerDegree
        for row in 0..<rows {
            for column in 0..<columns {
                let a = grid[row * (columns + 1) + column], b = grid[row * (columns + 1) + column + 1]
                let c = grid[(row + 1) * (columns + 1) + column + 1], d = grid[(row + 1) * (columns + 1) + column]
                let x = CGFloat(column) * unit, y = CGFloat(row) * unit
                for level in levels {
                    // Crossing points on the four edges: top, right, bottom, left.
                    var points: [CGPoint] = []
                    func cross(_ v1: Double, _ v2: Double, _ p1: CGPoint, _ p2: CGPoint) {
                        guard (v1 < level) != (v2 < level) else { return }
                        let t = CGFloat((level - v1) / (v2 - v1))
                        points.append(CGPoint(x: p1.x + (p2.x - p1.x) * t, y: p1.y + (p2.y - p1.y) * t))
                    }
                    let tl = CGPoint(x: x, y: y), tr = CGPoint(x: x + unit, y: y)
                    let br = CGPoint(x: x + unit, y: y + unit), bl = CGPoint(x: x, y: y + unit)
                    cross(a, b, tl, tr); cross(b, c, tr, br); cross(c, d, br, bl); cross(d, a, bl, tl)
                    guard points.count >= 2 else { continue }
                    let key = (row / cellsPerBucket) * 1000 + column / cellsPerBucket
                    let path = paths[key] ?? CGMutablePath()
                    path.move(to: points[0]); path.addLine(to: points[1])
                    if points.count == 4 { path.move(to: points[2]); path.addLine(to: points[3]) }
                    paths[key] = path
                }
            }
        }
        let side = CGFloat(cellsPerBucket) * unit
        return paths.map { key, path in
            AtlasWorld.Bucket(rect: CGRect(x: CGFloat(key % 1000) * side, y: CGFloat(key / 1000) * side,
                                           width: side, height: side), path: path)
        }
    }

    private static func fractal(_ x: Double, _ y: Double, seed: Int) -> Double {
        var total = 0.0, amplitude = 1.0, frequency = 1.0, norm = 0.0
        for octave in 0..<4 {
            total += amplitude * noise(x * frequency, y * frequency, seed: seed + octave * 31)
            norm += amplitude; amplitude *= 0.5; frequency *= 2
        }
        return total / norm * 2 - 1
    }

    private static func noise(_ x: Double, _ y: Double, seed: Int) -> Double {
        let x0 = floor(x), y0 = floor(y)
        let fx = x - x0, fy = y - y0
        let u = fx * fx * (3 - 2 * fx), v = fy * fy * (3 - 2 * fy)
        func corner(_ i: Double, _ j: Double) -> Double {
            var h = UInt64(bitPattern: Int64(i) &* 374_761_393 &+ Int64(j) &* 668_265_263 &+ Int64(seed) &* 2_147_483_647)
            h = (h ^ (h >> 13)) &* 1_274_126_177
            return Double((h ^ (h >> 16)) & 0xFFFF) / 65_535
        }
        let top = corner(x0, y0) * (1 - u) + corner(x0 + 1, y0) * u
        let bottom = corner(x0, y0 + 1) * (1 - u) + corner(x0 + 1, y0 + 1) * u
        return top * (1 - v) + bottom * v
    }

    private func smoothstep(_ low: Double, _ high: Double, _ value: Double) -> Double {
        let t = max(0, min(1, (value - low) / (high - low)))
        return t * t * (3 - 2 * t)
    }

    private static func distance(_ point: (Double, Double), to line: [(Double, Double)]) -> Double {
        var best = Double.infinity
        for (a, b) in zip(line, line.dropFirst()) {
            let dx = b.0 - a.0, dy = b.1 - a.1
            let t = max(0, min(1, ((point.0 - a.0) * dx + (point.1 - a.1) * dy) / (dx * dx + dy * dy)))
            best = min(best, hypot(point.0 - (a.0 + t * dx), point.1 - (a.1 + t * dy)))
        }
        return best
    }
}

private final class AtlasTileLayer: CATiledLayer {
    // CATiledLayer draws on background threads; everything read here is immutable.
    nonisolated(unsafe) var world: AtlasWorld?
    private static let colors = (
        water: UIColor(AtlasInk.water).cgColor, waterLine: UIColor(AtlasInk.waterLine).cgColor,
        land: UIColor(AtlasInk.land).cgColor, border: UIColor(AtlasInk.border).withAlphaComponent(0.55).cgColor,
        contour: UIColor(AtlasInk.contour).withAlphaComponent(0.45).cgColor,
        graticule: UIColor(AtlasInk.graticule).withAlphaComponent(0.3).cgColor
    )

    init(world: AtlasWorld, scale: CGFloat) {
        self.world = world
        super.init()
        contentsScale = scale
        tileSize = CGSize(width: 512, height: 512)
        levelsOfDetail = 9
        levelsOfDetailBias = 4
        bounds = CGRect(origin: .zero, size: AtlasWorld.size)
        anchorPoint = .zero
        position = .zero
    }
    override init(layer: Any) {
        world = (layer as? AtlasTileLayer)?.world
        super.init(layer: layer)
    }
    required init?(coder: NSCoder) { fatalError("Use init(world:scale:)") }
    override class func fadeDuration() -> CFTimeInterval { 0.15 }

    override func draw(in context: CGContext) {
        guard let world else { return }
        let colors = Self.colors
        // Map points per screen point, so lines keep a printed width at every zoom.
        let zoom = max(0.05, hypot(context.ctm.a, context.ctm.b) / contentsScale)
        let px = 1 / zoom
        let clip = context.boundingBoxOfClipPath
        let reach = clip.insetBy(dx: -12 * px, dy: -12 * px)
        let nearby = world.countries.filter { $0.bounds.intersects(reach) }

        context.setFillColor(colors.water)
        context.fill(clip)

        // Water lining: thin parallel lines along every coast, as on old engraved maps.
        context.setLineJoin(.round)
        for (distance, alpha) in [(11.0, 0.35), (7.0, 0.55), (3.5, 0.8)] as [(CGFloat, CGFloat)] {
            for (width, color) in [(2 * distance + 0.9, colors.waterLine.copy(alpha: alpha)!), (2 * distance - 0.9, colors.water)] {
                context.setStrokeColor(color)
                context.setLineWidth(width * px)
                for country in nearby { context.addPath(country.path) }
                context.strokePath()
            }
        }

        // Land, then the forest and highland washes inside it.
        context.setFillColor(colors.land)
        for country in nearby { context.addPath(country.path); context.fillPath(using: .evenOdd) }
        if !nearby.isEmpty {
            context.saveGState()
            for country in nearby { context.addPath(country.path) }
            context.clip(using: .evenOdd)
            for tint in world.tints {
                // All buckets in one fill, so no seams show where buckets meet.
                for bucket in tint.buckets where bucket.rect.intersects(clip) { context.addPath(bucket.path) }
                if !context.isPathEmpty {
                    context.setFillColor(tint.color)
                    context.fillPath(using: .winding)
                }
            }
            context.setStrokeColor(colors.contour)
            context.setLineWidth(0.6 * px)
            for bucket in world.contours where bucket.rect.intersects(clip) { context.addPath(bucket.path) }
            context.strokePath()
            context.restoreGState()
        }

        // Borders between countries, light so the coast stays the strongest line.
        context.setStrokeColor(colors.border)
        context.setLineWidth(0.5 * px)
        for country in nearby { context.addPath(country.path) }
        context.strokePath()

        // The graticule: every 10°, a little stronger every 30°.
        for major in [false, true] {
            context.setStrokeColor(major ? colors.graticule.copy(alpha: 0.5)! : colors.graticule)
            context.setLineWidth((major ? 0.7 : 0.45) * px)
            for longitude in stride(from: -180.0, through: 180, by: 10) where major == (Int(longitude) % 30 == 0) {
                let x = AtlasWorld.point(longitude: longitude, latitude: 0).x
                guard x >= clip.minX - 1, x <= clip.maxX + 1 else { continue }
                context.move(to: CGPoint(x: x, y: clip.minY)); context.addLine(to: CGPoint(x: x, y: clip.maxY))
            }
            for latitude in stride(from: -80.0, through: 80, by: 10) where major == (Int(latitude) % 30 == 0) {
                let y = AtlasWorld.point(longitude: 0, latitude: latitude).y
                guard y >= clip.minY - 1, y <= clip.maxY + 1 else { continue }
                context.move(to: CGPoint(x: clip.minX, y: y)); context.addLine(to: CGPoint(x: clip.maxX, y: y))
            }
            context.strokePath()
        }

        UIGraphicsPushContext(context)
        AtlasLettering.draw(in: clip, zoom: zoom)
        UIGraphicsPopContext()
    }
}

/// Ocean names, degree marks and two old voyages: the bits that make it read as an atlas.
private enum AtlasLettering {
    struct Label { let text: String; let longitude: Double; let latitude: Double; let size: CGFloat }
    static let oceans = [
        Label(text: "NORTH ATLANTIC OCEAN", longitude: -42, latitude: 34, size: 13),
        Label(text: "SOUTH ATLANTIC OCEAN", longitude: -16, latitude: -26, size: 13),
        Label(text: "PACIFIC OCEAN", longitude: -140, latitude: 12, size: 15),
        Label(text: "PACIFIC OCEAN", longitude: 165, latitude: 20, size: 15),
        Label(text: "INDIAN OCEAN", longitude: 78, latitude: -22, size: 15),
        Label(text: "ARCTIC OCEAN", longitude: 0, latitude: 79, size: 12),
        Label(text: "SOUTHERN OCEAN", longitude: 40, latitude: -60, size: 12),
        Label(text: "Gulf of Mexico", longitude: -90, latitude: 25, size: 7),
        Label(text: "North Sea", longitude: 3.5, latitude: 56, size: 3),
        Label(text: "Baltic Sea", longitude: 19, latitude: 56, size: 2.4),
        Label(text: "Mediterranean Sea", longitude: 17, latitude: 35, size: 4),
        Label(text: "Atlantic Ocean", longitude: -72.6, latitude: 40.05, size: 1.4),
        Label(text: "Long Island Sound", longitude: -72.95, latitude: 41.12, size: 0.9),
    ]
    struct Voyage { let stops: [(Double, Double)]; let dates: [String] }
    static let voyages = [
        Voyage(stops: [(-9.1, 38.7), (-17, 28), (-24, 15.5), (-33, -2), (-38.5, -13)],
               dates: ["MAR. 20-22", "MAR. 25-27", "APR. 3-5", "APR. 19"]),
        Voyage(stops: [(18.4, -34.4), (34, -30), (47.5, -19), (60, -2), (72.8, 18.9)],
               dates: ["JUN. 2", "JUN. 11-14", "JUL. 1-3", "JUL. 20"]),
        Voyage(stops: [(-74, 40.6), (-60, 43), (-40, 49), (-12, 51.5), (-1, 50.8)],
               dates: ["SEPT. 3-5", "SEPT. 12", "SEPT. 21", "OCT. 1"]),
    ]

    static func draw(in clip: CGRect, zoom: CGFloat) {
        let ink = UIColor(AtlasInk.oceanLabel)
        for label in oceans {
            let center = AtlasWorld.point(longitude: label.longitude, latitude: label.latitude)
            // Skip names too small to read at this zoom, and those outside the tile.
            guard label.size * zoom >= 6, label.size * zoom <= 40,
                  clip.insetBy(dx: -label.size * 20, dy: -label.size * 2).contains(center) else { continue }
            let font = serifItalic(label.size)
            let text = NSAttributedString(string: label.text, attributes: [
                .font: font, .foregroundColor: ink, .kern: label.size * 0.35])
            let size = text.size()
            text.draw(at: CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2))
        }

        let red = UIColor(AtlasInk.route)
        for voyage in voyages {
            let points = voyage.stops.map { AtlasWorld.point(longitude: $0.0, latitude: $0.1) }
            let bounds = points.reduce(CGRect.null) { $0.union(CGRect(origin: $1, size: .zero)) }
            guard bounds.insetBy(dx: -40, dy: -40).intersects(clip) else { continue }
            let path = UIBezierPath()
            path.move(to: points[0])
            for (a, b) in zip(points, points.dropFirst()) {
                // A gentle curve between ports, bowed to one side like a sailing line.
                let mid = CGPoint(x: (a.x + b.x) / 2 + (b.y - a.y) * 0.12, y: (a.y + b.y) / 2 - (b.x - a.x) * 0.12)
                path.addQuadCurve(to: b, controlPoint: mid)
            }
            path.lineWidth = 1.3 / zoom
            path.setLineDash([5 / zoom, 3.5 / zoom], count: 2, phase: 0)
            red.setStroke()
            path.stroke()
            let size = 8.5 / zoom
            guard size * zoom >= 6 else { continue }
            for (index, date) in voyage.dates.enumerated() {
                let a = points[index], b = points[index + 1]
                let text = NSAttributedString(string: date, attributes: [
                    .font: serifItalic(size, weight: .semibold), .kern: 0.5 / zoom, .foregroundColor: red])
                text.draw(at: CGPoint(x: (a.x + b.x) / 2 + 4 / zoom, y: (a.y + b.y) / 2))
            }
            for point in points {
                let dot = UIBezierPath(ovalIn: CGRect(x: point.x - 2.2 / zoom, y: point.y - 2.2 / zoom, width: 4.4 / zoom, height: 4.4 / zoom))
                red.setFill(); dot.fill()
            }
        }
    }

    private static func serifItalic(_ size: CGFloat, weight: UIFont.Weight = .medium) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight).fontDescriptor
        let descriptor = (base.withDesign(.serif) ?? base).withSymbolicTraits(.traitItalic) ?? base
        return UIFont(descriptor: descriptor, size: size)
    }
}
