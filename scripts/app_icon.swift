// Draws the app icon in the app's atlas style: a piece of school-atlas map with the
// yellow "Atlas" title tape on top. Uses the bundled Natural Earth countries.
// Run on macOS from the repository root. Without arguments it overwrites
// ios/Atlas/Assets.xcassets/AppIcon.appiconset/AppIcon.png.
//
//   swift scripts/app_icon.swift [output.png]
//   swift scripts/app_icon.swift --backdrop [output.png]   (the website's wide map, no title)
//
// Output: 1024 x 1024 PNG without alpha, as App Store icons require, or a 3000 x 1500 map.

import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let arguments = Array(CommandLine.arguments.dropFirst())
let backdrop = arguments.first == "--backdrop"
let paths = arguments.filter { $0 != "--backdrop" }
let output = paths.first ?? (backdrop ? "website/assets/atlas-map.png"
    : "ios/Atlas/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
let width = backdrop ? 3000 : 1024, height = backdrop ? 1500 : 1024
let size = width

// The atlas palette (matches AtlasInk and the Color extension in the app).
func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}
let water = rgb(0xBDDED9), waterLine = rgb(0x7DB3B3), land = rgb(0xF2E8CC)
let border = rgb(0x9E8566, 0.6), graticule = rgb(0x4D7A87, 0.35), route = rgb(0xB83A2E)
let ink = rgb(0x1C2629), yellow = rgb(0xFFC943), forest = rgb(0x73945F, 0.45)

// The icon: the eastern Atlantic, Iberia and the bulge of West Africa, like the home screen.
// The backdrop: the North Atlantic from New York to Europe.
let west = backdrop ? -82.0 : -34.0, east = backdrop ? 8.0 : 6.0, north = backdrop ? 62.0 : 50.0
let pxPerDegree = Double(size) / (east - west)
func point(_ longitude: Double, _ latitude: Double) -> CGPoint {
    CGPoint(x: (longitude - west) * pxPerDegree, y: (north - latitude) * pxPerDegree)
}

// Countries, as paths in pixel space.
struct Collection: Decodable {
    struct Feature: Decodable { let geometry: Geometry }
    struct Geometry: Decodable {
        let type: String
        let polygons: [[[[Double]]]]
        enum Keys: CodingKey { case type, coordinates }
        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: Keys.self)
            type = try values.decode(String.self, forKey: .type)
            polygons = type == "Polygon" ? [try values.decode([[[Double]]].self, forKey: .coordinates)]
                : try values.decode([[[[Double]]]].self, forKey: .coordinates)
        }
    }
    let features: [Feature]
}
let url = URL(fileURLWithPath: "maps/world-countries/areas-lowres.geojson")
let collection = try JSONDecoder().decode(Collection.self, from: Data(contentsOf: url))
let countries: [CGPath] = collection.features.map { feature in
    let path = CGMutablePath()
    for polygon in feature.geometry.polygons {
        for ring in polygon {
            path.addLines(between: ring.map { point($0[0], $0[1]) })
            path.closeSubpath()
        }
    }
    return path
}
let canvas = CGRect(x: 0, y: 0, width: width, height: height)
let visible = countries.filter { $0.boundingBoxOfPath.intersects(canvas.insetBy(dx: -60, dy: -60)) }

// RGB without alpha.
let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
// Work top-down, like the map.
context.translateBy(x: 0, y: CGFloat(height))
context.scaleBy(x: 1, y: -1)

context.setFillColor(water)
context.fill(canvas)

// Water lining along the coasts.
context.setLineJoin(.round)
for (distance, alpha) in [(34.0, 0.35), (22.0, 0.55), (11.0, 0.8)] as [(CGFloat, CGFloat)] {
    for (width, color) in [(2 * distance + 3, waterLine.copy(alpha: alpha)!), (2 * distance - 3, water)] {
        context.setStrokeColor(color)
        context.setLineWidth(width)
        for path in visible { context.addPath(path) }
        context.strokePath()
    }
}

// Land, then light borders.
context.setFillColor(land)
for path in visible { context.addPath(path); context.fillPath(using: .evenOdd) }
context.setStrokeColor(border)
context.setLineWidth(2)
for path in visible { context.addPath(path) }
context.strokePath()

// The graticule, every 10°.
context.setStrokeColor(graticule)
context.setLineWidth(2)
let south = north - Double(height) / pxPerDegree
for longitude in stride(from: (west / 10).rounded(.up) * 10, through: east, by: 10) {
    context.move(to: point(longitude, north)); context.addLine(to: point(longitude, south))
}
for latitude in stride(from: (south / 10).rounded(.down) * 10 + 10, to: north, by: 10) {
    context.move(to: point(west, latitude)); context.addLine(to: point(east, latitude))
}
context.strokePath()

// Red voyages, dashed: from Lisbon past the Canaries and Cape Verde, and (backdrop) New York to Lisbon.
context.setStrokeColor(route)
context.setLineWidth(6)
context.setLineCap(.round)
context.setLineDash(phase: 0, lengths: [18, 13])
// Each voyage: its course, and the ports along it that get a dot.
var voyages = [(stops: [point(-9.1, 38.7), point(-17, 28), point(-24, 15.5), point(-34, 8)], ports: [0, 1, 2])]
if backdrop {
    voyages.append((stops: [point(-74, 40.6), point(-60, 43), point(-40, 46), point(-20, 43), point(-9.1, 38.7)], ports: [0]))
}
for (stops, _) in voyages {
    context.move(to: stops[0])
    for (a, b) in zip(stops, stops.dropFirst()) {
        let mid = CGPoint(x: (a.x + b.x) / 2 + (b.y - a.y) * 0.12, y: (a.y + b.y) / 2 - (b.x - a.x) * 0.12)
        context.addQuadCurve(to: b, control: mid)
    }
    context.strokePath()
}
context.setLineDash(phase: 0, lengths: [])
context.setFillColor(route)
for (stops, ports) in voyages {
    for stop in ports.map({ stops[$0] }) { context.fillEllipse(in: CGRect(x: stop.x - 11, y: stop.y - 11, width: 22, height: 22)) }
}

// The backdrop has no title tape; the page draws its own.
if backdrop {
    let image = context.makeImage()!
    let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: output) as CFURL,
                                                      UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Could not write \(output)") }
    print("Wrote \(output)")
    exit(0)
}

// The title tape: black New York on yellow, tilted like a pasted label, with a hard shadow.
let fontSize: CGFloat = 300
let base = NSFont.systemFont(ofSize: fontSize, weight: .black)
let font = NSFont(descriptor: base.fontDescriptor.withDesign(.serif) ?? base.fontDescriptor, size: fontSize) ?? base
let title = NSAttributedString(string: "Atlas", attributes: [.font: font, .foregroundColor: NSColor(cgColor: ink)!,
                                                              .kern: -6])
let line = CTLineCreateWithAttributedString(title)
let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
let padX: CGFloat = 44, padY: CGFloat = 34
let tape = CGRect(x: -bounds.width / 2 - padX, y: -bounds.height / 2 - padY,
                  width: bounds.width + 2 * padX, height: bounds.height + 2 * padY)
context.saveGState()
context.translateBy(x: CGFloat(size) / 2, y: CGFloat(size) * 0.5)
context.rotate(by: -4 * .pi / 180)
context.setFillColor(ink.copy(alpha: 0.18)!)
context.fill(tape.offsetBy(dx: 10, dy: 14))
context.setFillColor(yellow)
context.fill(tape)
// Core Text draws upward; flip back for the text only.
context.scaleBy(x: 1, y: -1)
context.textPosition = CGPoint(x: -bounds.width / 2 - bounds.minX, y: -bounds.height / 2 - bounds.minY)
CTLineDraw(line, context)
context.restoreGState()

let image = context.makeImage()!
let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: output) as CFURL,
                                                  UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Could not write \(output)") }
print("Wrote \(output)")
