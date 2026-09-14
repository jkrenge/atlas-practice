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
    var highlight: String? = nil
    var selected: String? = nil
    var revealLabels = false
    var acceptsAnswers = true
    var onSelect: (String) -> Void
    @State private var viewport = MapViewport()
    @State private var hint = "Pinch to zoom. Drag to move."

    var body: some View {
        VStack(spacing: 0) {
            MapCanvas(pack: pack, highlight: highlight, selected: selected, revealLabels: revealLabels,
                      acceptsAnswers: acceptsAnswers, viewport: $viewport) { hit in
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
                Button { viewport.scale = min(8, viewport.scale * 1.5) }
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
    }
}

private struct MapCanvas: UIViewRepresentable {
    let pack: MapPack
    let highlight: String?
    let selected: String?
    let revealLabels: Bool
    let acceptsAnswers: Bool
    @Binding var viewport: MapViewport
    let onSelect: (MapHit) -> Void

    func makeUIView(context: Context) -> GeographicMapView { GeographicMapView(pack: pack) }
    func updateUIView(_ view: GeographicMapView, context: Context) {
        view.highlight = highlight
        view.selected = selected
        view.revealLabels = revealLabels
        view.acceptsAnswers = acceptsAnswers
        view.viewport = viewport
        view.onViewport = { viewport = $0 }
        view.onSelect = onSelect
        view.accessibilityLabel = highlight != nil && !revealLabels ? "Map with one highlighted area" : "Map of \(pack.manifest.name)"
        view.accessibilityValue = "\(Int(viewport.scale * 100)) percent zoom"
        view.accessibilityHint = "Use zoom controls to enlarge the map. In Find the area, an area list is also available."
        view.setNeedsDisplay()
    }
}

private final class GeographicMapView: UIView, UIGestureRecognizerDelegate {
    let pack: MapPack
    var layout: MapLayout?
    var viewport = MapViewport()
    var highlight: String?
    var selected: String?
    var revealLabels = false
    var acceptsAnswers = true
    var onSelect: ((MapHit) -> Void)?
    var onViewport: ((MapViewport) -> Void)?
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
        if bounds.width > 0, bounds.height > 0, layout?.size != bounds.size {
            layout = MapLayout(pack: pack, size: bounds.size)
            setNeedsDisplay()
        }
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(), let layout else { return }
        context.saveGState()
        context.translateBy(x: bounds.midX + viewport.offset.width, y: bounds.midY + viewport.offset.height)
        context.scaleBy(x: viewport.scale, y: viewport.scale)
        context.translateBy(x: -bounds.midX, y: -bounds.midY)
        for shape in layout.shapes {
            let color: UIColor
            if shape.id == highlight { color = UIColor(Color.atlasTeal) }
            else if shape.id == selected { color = UIColor(red: 0.62, green: 0.30, blue: 0.16, alpha: 1) }
            else { color = layout.eligibleIDs.contains(shape.id) ? UIColor(red: 0.98, green: 0.97, blue: 0.91, alpha: 1) : .systemGray3 }
            context.addPath(shape.path)
            context.setFillColor(color.cgColor)
            context.fillPath(using: .evenOdd)
            context.addPath(shape.path)
            context.setStrokeColor(UIColor(Color.atlasInk).withAlphaComponent(0.55).cgColor)
            context.setLineWidth(0.8 / viewport.scale)
            context.strokePath()
        }
        if let shape = layout.shapes.first(where: { $0.id == highlight }) {
            context.addPath(shape.path)
            context.setStrokeColor(UIColor(Color.atlasInk).cgColor)
            context.setLineWidth(3 / viewport.scale)
            context.strokePath()
        }
        context.restoreGState()

        if revealLabels {
            for shape in layout.shapes where layout.eligibleIDs.contains(shape.id) && !layout.callouts.contains(where: { $0.id == shape.id }) {
                let anchor = viewport.screen(shape.anchor, size: bounds.size)
                let title = pack.id == "us-states" ? String(shape.id.suffix(2)) : (pack.area(shape.id)?.name ?? "")
                let color: UIColor = shape.id == highlight || shape.id == selected ? .white : UIColor(Color.atlasInk)
                drawLabel(title, center: anchor, font: .systemFont(ofSize: 11, weight: .semibold), color: color)
            }
        }
        for callout in layout.callouts {
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
    }

    private func drawLabel(_ text: String, center: CGPoint, font: UIFont, color: UIColor) {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let size = (text as NSString).size(withAttributes: attributes)
        (text as NSString).draw(at: CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2), withAttributes: attributes)
    }
    @objc private func tapped(_ gesture: UITapGestureRecognizer) {
        guard acceptsAnswers, let layout else { return }
        onSelect?(layout.hit(gesture.location(in: self), viewport: viewport))
    }
    @objc private func panned(_ gesture: UIPanGestureRecognizer) {
        if gesture.state == .began { gestureStart = viewport }
        let translation = gesture.translation(in: self)
        viewport.offset = CGSize(width: gestureStart.offset.width + translation.x, height: gestureStart.offset.height + translation.y)
        onViewport?(viewport)
        setNeedsDisplay()
    }
    @objc private func pinched(_ gesture: UIPinchGestureRecognizer) {
        if gesture.state == .began { gestureStart = viewport; pinchAnchor = gesture.location(in: self) }
        viewport = gestureStart
        viewport.zoom(to: gestureStart.scale * gesture.scale, anchor: pinchAnchor, size: bounds.size)
        onViewport?(viewport)
        setNeedsDisplay()
    }
}
