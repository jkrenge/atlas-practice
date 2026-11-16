import SwiftUI
import UIKit

extension Color {
    static let atlasBlue = Color(red: 0.14, green: 0.20, blue: 0.77)
    static let atlasInk = Color(red: 0.12, green: 0.16, blue: 0.31)
    static let atlasMuted = Color(red: 0.24, green: 0.29, blue: 0.57)
    static let atlasPaper = Color(red: 0.95, green: 0.96, blue: 0.98)
    static let atlasSurface = Color.white
    static let atlasSea = Color(red: 0.89, green: 0.92, blue: 0.98)
    static let atlasLine = atlasBlue.opacity(0.35)
    // Wrong answers stay distinct from the blue target and also have text labels.
    static let atlasClay = Color(red: 0.34, green: 0.35, blue: 0.40)
}

struct MapPreview: UIViewRepresentable {
    let pack: MapPack
    func makeUIView(context: Context) -> MapPreviewView {
        let view = MapPreviewView(pack: pack)
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        return view
    }
    func updateUIView(_ view: MapPreviewView, context: Context) {}
}

final class MapPreviewView: UIView {
    private let pack: MapPack

    init(pack: MapPack) {
        self.pack = pack
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false
        contentMode = .redraw
    }

    required init?(coder: NSCoder) { fatalError("Use init(pack:)") }

    override func draw(_ rect: CGRect) {
        guard bounds.width > 0, bounds.height > 32,
              let context = UIGraphicsGetCurrentContext() else { return }
        let layout = MapLayout(pack: pack, size: bounds.size, includesCallouts: false)
        for shape in layout.shapes {
            context.saveGState()
            context.concatenate(shape.transform)
            context.addPath(shape.previewPath)
            context.setFillColor((layout.eligibleIDs.contains(shape.id)
                ? UIColor(Color.atlasSurface) : .systemGray3).cgColor)
            context.setStrokeColor(UIColor(Color.atlasBlue).cgColor)
            context.setLineWidth(0.8 / shape.transform.a)
            context.drawPath(using: .eoFillStroke)
            context.restoreGState()
        }
    }
}

struct MapView: View {
    let pack: MapPack
    var canvasHeight: CGFloat? = 320
    var fullscreen = false
    var resetID: UUID? = nil
    var highlight: String? = nil
    var selected: String? = nil
    var revealLabels = false
    var acceptsAnswers = true
    var guess: MapPin? = nil
    var target: MapPin? = nil
    var onLocation: ((MapPin) -> Void)? = nil
    var onSelect: (String) -> Void
    @State private var viewport = MapViewport()
    @State private var hint = "Pinch to zoom. Drag to move."
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if fullscreen {
                canvas
                    .overlay(alignment: .bottomTrailing) {
                        HStack(spacing: 8) {
                            if hint != "Pinch to zoom. Drag to move." { mapHint }
                            Spacer(minLength: 0)
                            mapControls
                        }.padding(12)
                    }
                    .background(Color.atlasSea)
            } else {
                framedMap
            }
        }
        .onChange(of: resetID) { _, _ in
            viewport = MapViewport()
            hint = "Pinch to zoom. Drag to move."
        }
    }

    private var canvas: some View {
        MapCanvas(pack: pack, highlight: highlight, selected: selected, revealLabels: revealLabels,
                  acceptsAnswers: acceptsAnswers, guess: guess, target: target, onLocation: onLocation, viewport: $viewport) { hit in
            switch hit {
            case .area(let id): hint = "Pinch to zoom. Drag to move."; onSelect(id)
            case .ambiguous: hint = "Close to a border. Zoom in and tap again."
            case .water: hint = "Tap inside an area or use a numbered marker."
            }
        }
        .frame(height: canvasHeight)
        .accessibilityIdentifier("geographicMap")
    }

    private var framedMap: some View {
        VStack(spacing: 0) {
            canvas
            Group {
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 4) { mapHint; HStack { Spacer(); mapControls } }
                } else {
                    HStack(spacing: 8) { mapHint; Spacer(minLength: 0); mapControls }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 4)
            .foregroundStyle(Color.atlasInk)
            .background(Color.atlasSurface)
        }
        .background(Color.atlasSea)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.atlasLine, lineWidth: 1))
    }

    private var mapHint: some View {
        Text(hint).font(.caption).foregroundStyle(Color.atlasMuted).fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("mapHint")
    }

    private var mapControls: some View {
        Group {
            HStack(spacing: 8) {
                Button { viewport.scale = max(1, viewport.scale / 1.5); if viewport.scale == 1 { viewport.offset = .zero } }
                label: { Image(systemName: "minus.magnifyingglass").font(.system(size: 20)).frame(width: 44, height: 44).atlasOutline(cornerRadius: 22).contentShape(Rectangle()) }
                    .accessibilityLabel("Zoom out")
                Button { viewport.scale = min(32, viewport.scale * 1.5) }
                label: { Image(systemName: "plus.magnifyingglass").font(.system(size: 20)).frame(width: 44, height: 44).atlasOutline(cornerRadius: 22).contentShape(Rectangle()) }
                    .accessibilityLabel("Zoom in")
                Button { viewport = MapViewport() }
                label: { Image(systemName: "arrow.counterclockwise").font(.system(size: 20)).frame(width: 44, height: 44).atlasOutline(cornerRadius: 22).contentShape(Rectangle()) }
                    .accessibilityLabel("Reset map")
            }.buttonStyle(AtlasPressStyle())
        }
    }
}

private struct MapCanvas: UIViewRepresentable {
    let pack: MapPack
    let highlight: String?
    let selected: String?
    let revealLabels: Bool
    let acceptsAnswers: Bool
    let guess: MapPin?
    let target: MapPin?
    let onLocation: ((MapPin) -> Void)?
    @Binding var viewport: MapViewport
    let onSelect: (MapHit) -> Void

    func makeUIView(context: Context) -> GeographicMapView { GeographicMapView(pack: pack) }
    func updateUIView(_ view: GeographicMapView, context: Context) {
        view.guess = guess
        view.target = target
        view.onLocation = onLocation
        view.highlight = highlight
        view.selected = selected
        view.revealLabels = revealLabels
        view.acceptsAnswers = acceptsAnswers
        view.applyViewport(viewport)
        view.onViewport = { viewport = $0 }
        view.onSelect = onSelect
        view.accessibilityLabel = highlight != nil && !revealLabels ? "Map with one highlighted area" : "Map of \(pack.manifest.name)"
        view.accessibilityValue = "\(Int(viewport.scale * 100)) percent zoom" + (guess.map { ". Guess at latitude \($0.coordinate.latitude.formatted(.number.precision(.fractionLength(2)))), longitude \($0.coordinate.longitude.formatted(.number.precision(.fractionLength(2))))" } ?? "")
        view.accessibilityHint = "Use zoom controls to enlarge the map. In Find the area, an area list is also available."
    }
}

private final class MapTileLayer: CATiledLayer {
    let layout: MapLayout
    let land: CGColor
    let excluded: CGColor
    let border: CGColor

    init(layout: MapLayout, scale: CGFloat) {
        self.layout = layout
        land = UIColor(Color.atlasSurface).cgColor
        excluded = UIColor.systemGray3.cgColor
        border = UIColor(Color.atlasBlue).cgColor
        super.init()
        contentsScale = scale
        tileSize = CGSize(width: 512, height: 512)
        levelsOfDetail = 6
        levelsOfDetailBias = 5
        bounds = CGRect(origin: .zero, size: layout.size)
        position = CGPoint(x: layout.size.width / 2, y: layout.size.height / 2)
    }

    override init(layer: Any) {
        let source = layer as! MapTileLayer
        layout = source.layout; land = source.land; excluded = source.excluded; border = source.border
        super.init(layer: layer)
    }
    required init?(coder: NSCoder) { fatalError("Use init(layout:scale:)") }
    override class func fadeDuration() -> CFTimeInterval { 0 }

    override func draw(in context: CGContext) {
        // CATiledLayer calls this on background threads. The geometry and colors
        // are immutable snapshots; drawing does not read UIKit or quiz state.
        let scale = hypot(context.ctm.a, context.ctm.b)
        let clip = context.boundingBoxOfClipPath.insetBy(dx: -1 / scale, dy: -1 / scale)
        for shape in layout.shapes where shape.bounds.intersects(clip) {
            context.saveGState()
            context.concatenate(shape.transform)
            context.addPath(shape.path)
            context.setFillColor(layout.eligibleIDs.contains(shape.id) ? land : excluded)
            context.setStrokeColor(border)
            context.setLineWidth(0.8 * contentsScale / (scale * shape.transform.a))
            context.drawPath(using: .eoFillStroke)
            context.restoreGState()
        }
    }
}

final class GeographicMapView: UIView, UIScrollViewDelegate {
    let pack: MapPack
    var showsAnnotations = true
    var guess: MapPin? { didSet { if guess != oldValue { annotations.setNeedsDisplay() } } }
    var target: MapPin? { didSet { if target != oldValue { annotations.setNeedsDisplay() } } }
    var onLocation: ((MapPin) -> Void)? {
        didSet { if (onLocation == nil) != (oldValue == nil) { annotations.setNeedsDisplay() } }
    }
    private(set) var layout: MapLayout?
    private(set) var viewport = MapViewport()
    var highlight: String? { didSet { if highlight != oldValue { updateSelection() } } }
    var selected: String? { didSet { if selected != oldValue { updateSelection() } } }
    var revealLabels = false { didSet { if revealLabels != oldValue { annotations.setNeedsDisplay() } } }
    var acceptsAnswers = true
    var onSelect: ((MapHit) -> Void)?
    var onViewport: ((MapViewport) -> Void)?
    private let scrollView = UIScrollView()
    private let content = UIView()
    private let geography = UIView()
    private let highlightLayer = CAShapeLayer()
    private let selectedLayer = CAShapeLayer()
    private let annotations = MapAnnotationsView()
    private var applyingViewport = false

    init(pack: MapPack) {
        self.pack = pack
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false
        clipsToBounds = true
        isAccessibilityElement = true
        accessibilityTraits = .image
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 32
        scrollView.bounces = false
        scrollView.bouncesZoom = false
        scrollView.decelerationRate = .fast
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.delaysContentTouches = false
        scrollView.addSubview(content)
        content.addSubview(geography)
        addSubview(scrollView)
        for layer in [selectedLayer, highlightLayer] {
            layer.fillRule = .evenOdd
            layer.strokeColor = UIColor(Color.atlasInk).cgColor
            geography.layer.addSublayer(layer)
        }
        selectedLayer.fillColor = UIColor(Color.atlasClay).cgColor
        highlightLayer.fillColor = UIColor(Color.atlasBlue).cgColor
        annotations.map = self
        annotations.backgroundColor = .clear
        annotations.isOpaque = false
        annotations.isUserInteractionEnabled = false
        addSubview(annotations)
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
        tap.require(toFail: scrollView.panGestureRecognizer)
        if let pinch = scrollView.pinchGestureRecognizer { tap.require(toFail: pinch) }
        addGestureRecognizer(tap)
    }
    required init?(coder: NSCoder) { fatalError("Use init(pack:)") }

    override func layoutSubviews() {
        super.layoutSubviews()
        annotations.frame = bounds
        guard bounds.width > 0, bounds.height > 0, layout?.size != bounds.size else { return }
        let current = viewport
        applyingViewport = true
        scrollView.frame = bounds
        scrollView.zoomScale = 1
        // Padding permits moving the atlas at its initial zoom, including insets.
        content.frame = CGRect(origin: .zero, size: CGSize(width: bounds.width * 3, height: bounds.height * 3))
        scrollView.contentSize = content.bounds.size
        geography.frame = CGRect(x: bounds.width, y: bounds.height, width: bounds.width, height: bounds.height)
        let fitted = MapLayout(pack: pack, size: bounds.size, includesCallouts: showsAnnotations)
        layout = fitted
        geography.layer.sublayers?.first(where: { $0 is CATiledLayer })?.removeFromSuperlayer()
        let tiles = MapTileLayer(layout: fitted, scale: traitCollection.displayScale)
        geography.layer.insertSublayer(tiles, at: 0)
        tiles.setNeedsDisplay()
        applyingViewport = false
        applyViewport(current)
        updateSelection()
    }

    func applyViewport(_ value: MapViewport) {
        // Timer updates must not replace a native gesture or its deceleration.
        guard !scrollView.isDragging, !scrollView.isDecelerating, !scrollView.isZooming else { return }
        applyingViewport = true
        viewport = value
        scrollView.zoomScale = value.scale
        scrollView.contentOffset = CGPoint(
            x: bounds.width * (1.5 * value.scale - 0.5) - value.offset.width,
            y: bounds.height * (1.5 * value.scale - 0.5) - value.offset.height)
        applyingViewport = false
        updateAnnotations()
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { content }
    func scrollViewDidScroll(_ scrollView: UIScrollView) { readViewport() }
    func scrollViewDidZoom(_ scrollView: UIScrollView) { readViewport() }
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { onViewport?(viewport) }
    }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { onViewport?(viewport) }
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        if !applyingViewport { onViewport?(viewport) }
    }

    private func readViewport() {
        guard !applyingViewport else { return }
        let value = MapViewport(scale: scrollView.zoomScale, offset: CGSize(
            width: bounds.width * (1.5 * scrollView.zoomScale - 0.5) - scrollView.contentOffset.x,
            height: bounds.height * (1.5 * scrollView.zoomScale - 0.5) - scrollView.contentOffset.y))
        guard value != viewport else { return }
        viewport = value
        updateAnnotations()
    }

    private func updateSelection() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (id, layer) in [(selected, selectedLayer), (highlight, highlightLayer)] {
            let shape = layout?.shapes.first { $0.id == id }
            layer.path = shape?.path
            layer.setAffineTransform(shape?.transform ?? .identity)
        }
        CATransaction.commit()
        updateAnnotations()
    }

    private func updateAnnotations() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (layer, width) in [(selectedLayer, CGFloat(0.8)), (highlightLayer, CGFloat(3))] {
            let lineWidth = width / (scrollView.zoomScale * layer.affineTransform().a)
            if layer.lineWidth != lineWidth { layer.lineWidth = lineWidth }
        }
        CATransaction.commit()
        if revealLabels || guess != nil || target != nil || (onLocation == nil && layout?.callouts.isEmpty == false) {
            annotations.setNeedsDisplay()
        }
        let value = "\(Int(viewport.scale * 100)) percent zoom" + (guess.map {
            ". Guess at latitude \($0.coordinate.latitude.formatted(.number.precision(.fractionLength(2)))), longitude \($0.coordinate.longitude.formatted(.number.precision(.fractionLength(2))))"
        } ?? "")
        if accessibilityValue != value { accessibilityValue = value }
    }

    fileprivate func drawAnnotations() {
        guard showsAnnotations else { return }
        guard let context = UIGraphicsGetCurrentContext(), let layout else { return }
        if revealLabels {
            var occupied: [CGRect] = []
            for shape in layout.shapes where layout.eligibleIDs.contains(shape.id) && !layout.callouts.contains(where: { $0.id == shape.id }) {
                let anchor = viewport.screen(shape.anchor, size: bounds.size)
                let title = pack.id == "us-states" ? String(shape.id.suffix(2)) : (pack.area(shape.id)?.name ?? "")
                let font = UIFont.systemFont(ofSize: 11, weight: .semibold)
                let labelSize = (title as NSString).size(withAttributes: [.font: font])
                let labelRect = CGRect(x: anchor.x - labelSize.width / 2, y: anchor.y - labelSize.height / 2,
                                       width: labelSize.width, height: labelSize.height).insetBy(dx: -3, dy: -3)
                if shape.id != highlight && (occupied.contains { $0.intersects(labelRect) } || !bounds.contains(labelRect)) { continue }
                occupied.append(labelRect)
                let color: UIColor = shape.id == highlight || shape.id == selected ? .white : UIColor(Color.atlasInk)
                drawLabel(title, center: anchor, font: .systemFont(ofSize: 11, weight: .semibold), color: color)
            }
        }
        for callout in layout.callouts where onLocation == nil && target == nil {
            guard let shape = layout.shapes.first(where: { $0.id == callout.id }) else { continue }
            let anchor = viewport.screen(shape.anchor, size: bounds.size)
            context.setStrokeColor(UIColor(Color.atlasInk).withAlphaComponent(0.5).cgColor)
            context.setLineWidth(1)
            context.move(to: anchor)
            context.addLine(to: callout.center)
            context.strokePath()
            context.setFillColor(UIColor(Color.atlasInk).cgColor)
            context.fillEllipse(in: CGRect(x: anchor.x - 2, y: anchor.y - 2, width: 4, height: 4))
            let active = callout.id == highlight
            let wrong = callout.id == selected && !active
            let box = UIBezierPath(roundedRect: callout.frame.insetBy(dx: 2, dy: 2), cornerRadius: 12)
            (active ? UIColor(Color.atlasBlue) : wrong ? UIColor(Color.atlasClay) : .white).setFill()
            box.fill()
            let title = revealLabels ? String(callout.id.suffix(2)) : String(callout.number)
            drawLabel(title, center: callout.center, font: .systemFont(ofSize: 14, weight: .bold),
                      color: active || wrong ? .white : UIColor(Color.atlasInk))
        }
        drawPin(guess, letter: "G", color: UIColor(Color.atlasClay), layout: layout)
        drawPin(target, letter: "A", color: UIColor(Color.atlasBlue), layout: layout)
    }

    private func drawPin(_ pin: MapPin?, letter: String, color: UIColor, layout: MapLayout) {
        guard let pin, let point = layout.screen(pin.coordinate, areaID: pin.regionID, viewport: viewport) else { return }
        let marker = UIBezierPath(ovalIn: CGRect(x: point.x - 12, y: point.y - 12, width: 24, height: 24))
        color.setFill(); marker.fill()
        UIColor.white.setStroke(); marker.lineWidth = 2; marker.stroke()
        drawLabel(letter, center: point, font: .systemFont(ofSize: 13, weight: .bold), color: .white)
    }

    private func drawLabel(_ text: String, center: CGPoint, font: UIFont, color: UIColor) {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let size = (text as NSString).size(withAttributes: attributes)
        (text as NSString).draw(at: CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2), withAttributes: attributes)
    }
    @objc private func tapped(_ gesture: UITapGestureRecognizer) {
        guard acceptsAnswers, let layout else { return }
        if let onLocation {
            if let pin = layout.locationPin(gesture.location(in: self), viewport: viewport) { onLocation(pin) }
        } else { onSelect?(layout.hit(gesture.location(in: self), viewport: viewport)) }
    }
}

private final class MapAnnotationsView: UIView {
    weak var map: GeographicMapView?
    override func draw(_ rect: CGRect) { map?.drawAnnotations() }
}
