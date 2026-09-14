import SwiftUI
import UIKit

extension Color {
    static let atlasInk = Color(red: 0.12, green: 0.23, blue: 0.24)
    static let atlasTeal = Color(red: 0.10, green: 0.40, blue: 0.37)
    static let atlasMuted = Color(red: 0.31, green: 0.40, blue: 0.39)
    static let atlasPaper = Color(red: 0.97, green: 0.96, blue: 0.93)
}

struct MapView: View {
    let pack: MapPack
    var canvasHeight: CGFloat = 320
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

    var body: some View {
        VStack(spacing: 0) {
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
            HStack(spacing: 8) {
                Text(hint).font(.caption).foregroundStyle(Color.atlasMuted).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("mapHint")
                Spacer(minLength: 0)
                Button { viewport.scale = max(1, viewport.scale / 1.5); if viewport.scale == 1 { viewport.offset = .zero } }
                label: { Image(systemName: "minus.magnifyingglass").font(.system(size: 20)).frame(width: 44, height: 44) }
                    .accessibilityLabel("Zoom out")
                Button { viewport.scale = min(32, viewport.scale * 1.5) }
                label: { Image(systemName: "plus.magnifyingglass").font(.system(size: 20)).frame(width: 44, height: 44) }
                    .accessibilityLabel("Zoom in")
                Button { viewport = MapViewport() }
                label: { Image(systemName: "arrow.counterclockwise").font(.system(size: 20)).frame(width: 44, height: 44) }
                    .accessibilityLabel("Reset map")
            }
            .padding(.horizontal, 12)
            .foregroundStyle(Color.atlasInk)
        }
        .background(Color(red: 0.90, green: 0.94, blue: 0.92))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .onChange(of: resetID) { _, _ in
            viewport = MapViewport()
            hint = "Pinch to zoom. Drag to move."
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

final class GeographicMapView: UIView, UIGestureRecognizerDelegate {
    let pack: MapPack
    var guess: MapPin? { didSet { if guess != oldValue { annotations.setNeedsDisplay() } } }
    var target: MapPin? { didSet { if target != oldValue { annotations.setNeedsDisplay() } } }
    var onLocation: ((MapPin) -> Void)? {
        didSet { if (onLocation == nil) != (oldValue == nil) { annotations.setNeedsDisplay() } }
    }
    private(set) var layout: MapLayout?
    var viewport = MapViewport() { didSet { if viewport != oldValue { updateViewport() } } }
    var highlight: String? { didSet { if highlight != oldValue { updateColors() } } }
    var selected: String? { didSet { if selected != oldValue { updateColors() } } }
    var revealLabels = false { didSet { if revealLabels != oldValue { annotations.setNeedsDisplay() } } }
    var acceptsAnswers = true
    var onSelect: ((MapHit) -> Void)?
    var onViewport: ((MapViewport) -> Void)?
    private let geography = CALayer()
    private var areaLayers: [CAShapeLayer] = []
    private let highlightOutline = CAShapeLayer()
    private let annotations = MapAnnotationsView()
    private var gestureStart = MapViewport()
    private var pinchAnchor = CGPoint.zero

    init(pack: MapPack) {
        self.pack = pack
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false
        clipsToBounds = true
        isAccessibilityElement = true
        accessibilityTraits = .image
        layer.addSublayer(geography)
        annotations.map = self
        annotations.backgroundColor = .clear
        annotations.isOpaque = false
        annotations.isUserInteractionEnabled = false
        addSubview(annotations)
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
        let pan = UIPanGestureRecognizer(target: self, action: #selector(panned))
        pan.maximumNumberOfTouches = 1
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(pinched))
        tap.require(toFail: pan)
        tap.require(toFail: pinch)
        [tap, pan, pinch].forEach { addGestureRecognizer($0) }
    }
    required init?(coder: NSCoder) { fatalError("Use init(pack:)") }

    override func layoutSubviews() {
        super.layoutSubviews()
        annotations.frame = bounds
        if bounds.width > 0, bounds.height > 0, layout?.size != bounds.size {
            layout = MapLayout(pack: pack, size: bounds.size)
            rebuildLayers()
        }
    }

    private func rebuildLayers() {
        guard let layout else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        geography.sublayers?.forEach { $0.removeFromSuperlayer() }
        areaLayers = layout.shapes.map { shape in
            let layer = CAShapeLayer()
            layer.path = shape.path
            layer.fillRule = .evenOdd
            layer.strokeColor = UIColor(Color.atlasInk).withAlphaComponent(0.55).cgColor
            geography.addSublayer(layer)
            return layer
        }
        highlightOutline.fillColor = nil
        highlightOutline.strokeColor = UIColor(Color.atlasInk).cgColor
        geography.addSublayer(highlightOutline)
        updateColors()
        updateViewport()
        CATransaction.commit()
    }

    private func updateColors() {
        guard let layout else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (shape, layer) in zip(layout.shapes, areaLayers) {
            let color: UIColor
            if shape.id == highlight { color = UIColor(Color.atlasTeal) }
            else if shape.id == selected { color = UIColor(red: 0.62, green: 0.30, blue: 0.16, alpha: 1) }
            else { color = layout.eligibleIDs.contains(shape.id) ? UIColor(red: 0.98, green: 0.97, blue: 0.91, alpha: 1) : .systemGray3 }
            layer.fillColor = color.cgColor
        }
        highlightOutline.path = layout.shapes.first { $0.id == highlight }?.path
        CATransaction.commit()
        annotations.setNeedsDisplay()
    }

    func applyViewport(_ value: MapViewport) {
        // SwiftUI can update the timer during a drag. Preserve the live native
        // gesture until its final viewport is published back to SwiftUI.
        guard !(gestureRecognizers ?? []).contains(where: {
            ($0 is UIPanGestureRecognizer || $0 is UIPinchGestureRecognizer) &&
                ($0.state == .began || $0.state == .changed)
        }) else { return }
        viewport = value
    }

    private func updateViewport() {
        // Reuse vector paths. Core Animation moves the map without repainting
        // every coastline on the main thread for every gesture frame.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        geography.setAffineTransform(CGAffineTransform(
            a: viewport.scale, b: 0, c: 0, d: viewport.scale,
            tx: bounds.midX * (1 - viewport.scale) + viewport.offset.width,
            ty: bounds.midY * (1 - viewport.scale) + viewport.offset.height))
        for layer in areaLayers { layer.lineWidth = 0.8 / viewport.scale }
        highlightOutline.lineWidth = 3 / viewport.scale
        CATransaction.commit()
        annotations.setNeedsDisplay()
        accessibilityValue = "\(Int(viewport.scale * 100)) percent zoom" + (guess.map {
            ". Guess at latitude \($0.coordinate.latitude.formatted(.number.precision(.fractionLength(2)))), longitude \($0.coordinate.longitude.formatted(.number.precision(.fractionLength(2))))"
        } ?? "")
    }

    fileprivate func drawAnnotations() {
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
            (active ? UIColor(Color.atlasTeal) : wrong ? UIColor(red: 0.62, green: 0.30, blue: 0.16, alpha: 1) : .white).setFill()
            box.fill()
            let title = revealLabels ? String(callout.id.suffix(2)) : String(callout.number)
            drawLabel(title, center: callout.center, font: .systemFont(ofSize: 14, weight: .bold),
                      color: active || wrong ? .white : UIColor(Color.atlasInk))
        }
        drawPin(guess, letter: "G", color: UIColor(red: 0.62, green: 0.30, blue: 0.16, alpha: 1), layout: layout)
        drawPin(target, letter: "A", color: UIColor(Color.atlasTeal), layout: layout)
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
    @objc private func panned(_ gesture: UIPanGestureRecognizer) {
        if gesture.state == .began { gestureStart = viewport }
        let translation = gesture.translation(in: self)
        viewport.offset = CGSize(width: gestureStart.offset.width + translation.x, height: gestureStart.offset.height + translation.y)
        if gesture.state == .ended || gesture.state == .cancelled { onViewport?(viewport) }
    }
    @objc private func pinched(_ gesture: UIPinchGestureRecognizer) {
        if gesture.state == .began { gestureStart = viewport; pinchAnchor = gesture.location(in: self) }
        var updated = gestureStart
        updated.zoom(to: gestureStart.scale * gesture.scale, anchor: pinchAnchor, size: bounds.size)
        viewport = updated
        if gesture.state == .ended || gesture.state == .cancelled { onViewport?(viewport) }
    }
}

private final class MapAnnotationsView: UIView {
    weak var map: GeographicMapView?
    override func draw(_ rect: CGRect) { map?.drawAnnotations() }
}
