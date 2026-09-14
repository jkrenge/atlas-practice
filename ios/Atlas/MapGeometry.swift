import Foundation
import CoreGraphics

// All rendering starts from longitude/latitude. Insets only affect presentation.
enum MapProjection {
    case equirectangular(longitude: Double, latitude: Double)
    case albers

    func forward(_ coordinate: Coordinate) -> CGPoint {
        switch self {
        case .equirectangular(let longitude, let latitude):
            let delta = Self.wrap(coordinate.longitude - longitude)
            return CGPoint(x: delta * cos(latitude * .pi / 180), y: coordinate.latitude - latitude)
        case .albers:
            let (n, c, rho0) = Self.albersConstants
            let theta = n * Self.wrap(coordinate.longitude + 96) * .pi / 180
            let rho = sqrt(c - 2 * n * sin(coordinate.latitude * .pi / 180)) / n
            return CGPoint(x: rho * sin(theta), y: rho0 - rho * cos(theta))
        }
    }

    func inverse(_ point: CGPoint) -> Coordinate {
        switch self {
        case .equirectangular(let longitude, let latitude):
            return Coordinate(Self.wrap(point.x / cos(latitude * .pi / 180) + longitude), point.y + latitude)
        case .albers:
            let (n, c, rho0) = Self.albersConstants
            let rho = hypot(point.x, rho0 - point.y)
            let theta = atan2(point.x, rho0 - point.y)
            return Coordinate(Self.wrap(theta / n * 180 / .pi - 96),
                              asin((c - rho * rho * n * n) / (2 * n)) * 180 / .pi)
        }
    }

    private static var albersConstants: (Double, Double, Double) {
        let p1 = 29.5 * Double.pi / 180, p2 = 45.5 * Double.pi / 180
        let n = (sin(p1) + sin(p2)) / 2
        let c = pow(cos(p1), 2) + 2 * n * sin(p1)
        return (n, c, sqrt(c - 2 * n * sin(37.5 * .pi / 180)) / n)
    }
    private static func wrap(_ longitude: Double) -> Double {
        var value = longitude
        while value > 180 { value -= 360 }
        while value < -180 { value += 360 }
        return value
    }
}

struct MapViewport: Equatable {
    var scale: CGFloat = 1
    var offset: CGSize = .zero
    func screen(_ point: CGPoint, size: CGSize) -> CGPoint {
        CGPoint(x: (point.x - size.width / 2) * scale + size.width / 2 + offset.width,
                y: (point.y - size.height / 2) * scale + size.height / 2 + offset.height)
    }
    func map(_ point: CGPoint, size: CGSize) -> CGPoint {
        CGPoint(x: (point.x - size.width / 2 - offset.width) / scale + size.width / 2,
                y: (point.y - size.height / 2 - offset.height) / scale + size.height / 2)
    }
    mutating func zoom(to newScale: CGFloat, anchor: CGPoint, size: CGSize) {
        let position = map(anchor, size: size)
        scale = min(32, max(1, newScale))
        offset = CGSize(width: anchor.x - size.width / 2 - (position.x - size.width / 2) * scale,
                        height: anchor.y - size.height / 2 - (position.y - size.height / 2) * scale)
        if scale == 1 { offset = .zero }
    }
}

struct MapRegion {
    let projection: MapProjection
    let bounds: CGRect
    let frame: CGRect
    var factor: CGFloat { min(frame.width / bounds.width, frame.height / bounds.height) }
    func point(_ coordinate: Coordinate) -> CGPoint {
        let point = projection.forward(coordinate)
        return CGPoint(x: frame.midX + (point.x - bounds.midX) * factor,
                       y: frame.midY - (point.y - bounds.midY) * factor)
    }
    func coordinate(_ point: CGPoint) -> Coordinate {
        projection.inverse(CGPoint(x: (point.x - frame.midX) / factor + bounds.midX,
                                  y: (frame.midY - point.y) / factor + bounds.midY))
    }
}

struct MapShape {
    let id: String
    let path: CGPath
    let anchor: CGPoint
    let region: Int
}

struct MapCallout {
    let id: String
    let number: Int
    let center: CGPoint
    var frame: CGRect { CGRect(x: center.x - 22, y: center.y - 22, width: 44, height: 44) }
}

enum MapHit: Equatable {
    case area(String), water, ambiguous
}

struct MapLayout {
    let size: CGSize
    let regions: [MapRegion]
    let shapes: [MapShape]
    let callouts: [MapCallout]
    let eligibleIDs: Set<String>

    init(pack: MapPack, size: CGSize) {
        self.size = size
        eligibleIDs = Set(pack.areas.map(\.id))
        let us = pack.id == "us-states"
        let smallIDs = us ? ["US-RI", "US-CT", "US-NJ", "US-DE"] :
            (pack.id == "germany-states" ? ["DE-HH", "DE-HB", "DE-BE"] : [])
        let usableWidth = size.width - (smallIDs.isEmpty ? 24 : 70)
        var groups: [(features: [GeoFeature], projection: MapProjection, frame: CGRect)] = []
        if us {
            groups = [
                (pack.features.filter { !["US-AK", "US-HI"].contains($0.id) }, .albers,
                 CGRect(x: 12, y: 12, width: usableWidth, height: size.height * 0.71)),
                (pack.features.filter { $0.id == "US-AK" }, .equirectangular(longitude: -154, latitude: 64),
                 CGRect(x: 16, y: size.height * 0.76, width: size.width * 0.40, height: size.height * 0.20)),
                (pack.features.filter { $0.id == "US-HI" }, .equirectangular(longitude: -157, latitude: 20),
                 CGRect(x: size.width * 0.47, y: size.height * 0.79, width: size.width * 0.25, height: size.height * 0.14))
            ]
        } else {
            let coordinates = pack.features.flatMap { $0.geometry.polygons.flatMap { $0.flatMap { $0 } } }
            let longitude = coordinates.map(\.longitude).reduce(0, +) / Double(coordinates.count)
            let latitude = coordinates.map(\.latitude).reduce(0, +) / Double(coordinates.count)
            groups = [(pack.features, .equirectangular(longitude: longitude, latitude: latitude),
                       CGRect(x: 12, y: 16, width: usableWidth, height: size.height - 32))]
        }
        var regions: [MapRegion] = []
        var shapes: [MapShape] = []
        for group in groups where !group.features.isEmpty {
            let points = group.features.flatMap { $0.geometry.polygons.flatMap { $0.flatMap { $0.map(group.projection.forward) } } }
            let x = points.map(\.x), y = points.map(\.y)
            let bounds = CGRect(x: x.min()!, y: y.min()!, width: x.max()! - x.min()!, height: y.max()! - y.min()!)
            let region = MapRegion(projection: group.projection, bounds: bounds, frame: group.frame)
            let regionIndex = regions.count
            regions.append(region)
            for feature in group.features {
                let path = CGMutablePath()
                var largestRing: [CGPoint] = []
                var largestArea: CGFloat = 0
                for polygon in feature.geometry.polygons {
                    for (index, ring) in polygon.enumerated() {
                        let points = ring.map(region.point)
                        path.addLines(between: points)
                        path.closeSubpath()
                        let area = abs(Self.signedArea(points))
                        if index == 0 && area > largestArea { largestRing = points; largestArea = area }
                    }
                }
                let anchor = Self.interiorPoint(path: path, ring: largestRing)
                shapes.append(MapShape(id: feature.id, path: path, anchor: anchor, region: regionIndex))
            }
        }
        self.regions = regions
        self.shapes = shapes
        let spacing: CGFloat = max(48, min(62, (size.height - 48) / CGFloat(max(1, smallIDs.count))))
        callouts = smallIDs.enumerated().map { index, id in
            MapCallout(id: id, number: index + 1,
                       center: CGPoint(x: size.width - 27, y: size.height * 0.20 + CGFloat(index) * spacing))
        }
    }

    func hit(_ screen: CGPoint, viewport: MapViewport, tolerance: CGFloat = 3) -> MapHit {
        if let callout = callouts.first(where: { $0.frame.contains(screen) }) { return .area(callout.id) }
        let point = viewport.map(screen, size: size)
        guard let shape = shapes.first(where: { $0.path.contains(point, using: .evenOdd) }) else { return .water }
        guard eligibleIDs.contains(shape.id) else { return .water }
        // Reject a tap near another eligible area instead of recording an uncertain answer.
        let delta = tolerance / viewport.scale
        for offset in [CGPoint(x: delta, y: 0), CGPoint(x: -delta, y: 0), CGPoint(x: 0, y: delta), CGPoint(x: 0, y: -delta)] {
            let neighbor = CGPoint(x: point.x + offset.x, y: point.y + offset.y)
            if shapes.contains(where: { $0.id != shape.id && eligibleIDs.contains($0.id) && $0.path.contains(neighbor, using: .evenOdd) }) {
                return .ambiguous
            }
        }
        return .area(shape.id)
    }

    func screen(_ coordinate: Coordinate, areaID: String, viewport: MapViewport) -> CGPoint? {
        guard let shape = shapes.first(where: { $0.id == areaID }) else { return nil }
        return viewport.screen(regions[shape.region].point(coordinate), size: size)
    }

    func coordinate(_ screen: CGPoint, viewport: MapViewport) -> Coordinate? {
        let point = viewport.map(screen, size: size)
        guard let shape = shapes.first(where: { $0.path.contains(point, using: .evenOdd) }) else { return nil }
        return regions[shape.region].coordinate(point)
    }

    // Point questions accept coastlines and water within a geographic inset.
    // Gaps between the differently projected US insets have no coordinate.
    func locationPin(_ screen: CGPoint, viewport: MapViewport) -> MapPin? {
        let point = viewport.map(screen, size: size)
        guard let index = regions.firstIndex(where: { $0.frame.contains(point) }),
              let shape = shapes.first(where: { $0.region == index }) else { return nil }
        let coordinate = regions[index].coordinate(point)
        guard coordinate.latitude.isFinite, coordinate.longitude.isFinite,
              (-90...90).contains(coordinate.latitude), (-180...180).contains(coordinate.longitude) else { return nil }
        return MapPin(coordinate: coordinate, regionID: shape.id)
    }

    private static func signedArea(_ ring: [CGPoint]) -> CGFloat {
        guard ring.count > 2 else { return 0 }
        return zip(ring, ring.dropFirst()).reduce(0) { $0 + $1.0.x * $1.1.y - $1.1.x * $1.0.y } / 2
    }
    private static func interiorPoint(path: CGPath, ring: [CGPoint]) -> CGPoint {
        let area = signedArea(ring)
        var center = CGPoint.zero
        if abs(area) > 0.00001 {
            for (a, b) in zip(ring, ring.dropFirst()) {
                let cross = a.x * b.y - b.x * a.y
                center.x += (a.x + b.x) * cross / (6 * area)
                center.y += (a.y + b.y) * cross / (6 * area)
            }
            if path.contains(center, using: .evenOdd) { return center }
        }
        let x = ring.map(\.x), y = ring.map(\.y)
        if let minX = x.min(), let maxX = x.max(), let minY = y.min(), let maxY = y.max() {
            for row in 1..<20 {
                for column in 1..<20 {
                    let point = CGPoint(x: minX + (maxX - minX) * CGFloat(column) / 20,
                                        y: minY + (maxY - minY) * CGFloat(row) / 20)
                    if path.contains(point, using: .evenOdd) { return point }
                }
            }
        }
        return ring.first ?? path.boundingBoxOfPath.origin
    }
}
