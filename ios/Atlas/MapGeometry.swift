import Foundation
import CoreGraphics

// All rendering starts from longitude/latitude. Insets only affect presentation.
enum MapProjection {
    case equirectangular(longitude: Double, latitude: Double)
    case mercator
    case albers

    func forward(_ coordinate: Coordinate) -> CGPoint {
        switch self {
        case .equirectangular(let longitude, let latitude):
            let delta = Self.wrap(coordinate.longitude - longitude)
            return CGPoint(x: delta * cos(latitude * .pi / 180), y: coordinate.latitude - latitude)
        case .mercator:
            // Mercator has no poles: clamp at 85°N, as web maps do, and at 76°S, so Antarctica
            // is a strip along the lower edge instead of the largest shape on the map.
            let latitude = min(85, max(-76, coordinate.latitude)) * .pi / 180
            return CGPoint(x: coordinate.longitude, y: log(tan(.pi / 4 + latitude / 2)) * 180 / .pi)
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
        case .mercator:
            return Coordinate(point.x, (2 * atan(exp(point.y * .pi / 180)) - .pi / 2) * 180 / .pi)
        case .albers:
            let (n, c, rho0) = Self.albersConstants
            let rho = hypot(point.x, rho0 - point.y)
            let theta = atan2(point.x, rho0 - point.y)
            return Coordinate(Self.wrap(theta / n * 180 / .pi - 96),
                              asin((c - rho * rho * n * n) / (2 * n)) * 180 / .pi)
        }
    }

    private static let albersConstants: (Double, Double, Double) = {
        let p1 = 29.5 * Double.pi / 180, p2 = 45.5 * Double.pi / 180
        let n = (sin(p1) + sin(p2)) / 2
        let c = pow(cos(p1), 2) + 2 * n * sin(p1)
        return (n, c, sqrt(c - 2 * n * sin(37.5 * .pi / 180)) / n)
    }()
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
    let previewPath: CGPath
    let anchor: CGPoint
    let region: Int
    let bounds: CGRect
    // The retained path is in prepared-map coordinates. Anchors and bounds
    // are fitted to the current canvas; hit testing uses the inverse fit.
    let transform: CGAffineTransform
    func contains(_ point: CGPoint) -> Bool {
        bounds.contains(point) && path.contains(point.applying(transform.inverted()), using: .evenOdd)
    }
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

    init(pack: MapPack, size: CGSize, includesCallouts: Bool = true) {
        self.size = size
        let prepared = pack.preparedLayout
        eligibleIDs = prepared.eligibleIDs
        let smallIDs = includesCallouts ? prepared.callouts.map(\.id) : []
        let frames = Self.frames(size: size, us: pack.id == "us-states", hasCallouts: !smallIDs.isEmpty)
        regions = zip(prepared.regions, frames).map { source, frame in
            MapRegion(projection: source.projection, bounds: source.bounds, frame: frame)
        }
        let transforms = zip(prepared.regions, regions).map { source, fitted in
            let scale = fitted.factor / source.factor
            return CGAffineTransform(a: scale, b: 0, c: 0, d: scale,
                                     tx: fitted.frame.midX - source.frame.midX * scale,
                                     ty: fitted.frame.midY - source.frame.midY * scale)
        }
        shapes = prepared.shapes.map { source in
            let transform = transforms[source.region]
            return MapShape(id: source.id, path: source.path, previewPath: source.previewPath, anchor: source.anchor.applying(transform),
                            region: source.region, bounds: source.bounds.applying(transform), transform: transform)
        }
        callouts = Self.callouts(ids: smallIDs, size: size)
    }

    // Prepare projection, paths, and interior anchors while loading the pack
    // off the main actor. Every preview and play canvas shares these paths.
    init(manifest: MapManifest, features: [GeoFeature]) {
        let size = CGSize(width: 1000, height: 1000)
        self.size = size
        let eligibleIDs = Set(manifest.areas.map(\.id))
        self.eligibleIDs = eligibleIDs
        let us = manifest.id == "us-states"
        let smallIDs = us ? ["US-RI", "US-CT", "US-NJ", "US-DE"] :
            (manifest.id == "germany-states" ? ["DE-HH", "DE-HB", "DE-BE"] : [])
        let frames = Self.frames(size: size, us: us, hasCallouts: !smallIDs.isEmpty)
        var groups: [(features: [GeoFeature], projection: MapProjection, frame: CGRect)] = []
        if us {
            groups = [
                (features.filter { !["US-AK", "US-HI"].contains($0.id) }, .albers, frames[0]),
                (features.filter { $0.id == "US-AK" }, .equirectangular(longitude: -154, latitude: 64), frames[1]),
                (features.filter { $0.id == "US-HI" }, .equirectangular(longitude: -157, latitude: 20), frames[2])
            ]
        } else if manifest.id == "world-countries" {
            // Centered on Greenwich: the source cuts polygons at ±180°, so no edge wraps across the map.
            groups = [(features, .mercator, frames[0])]
        } else {
            let coordinates = features.flatMap { $0.geometry.polygons.flatMap { $0.flatMap { $0 } } }
            let longitude = coordinates.map(\.longitude).reduce(0, +) / Double(coordinates.count)
            let latitude = coordinates.map(\.latitude).reduce(0, +) / Double(coordinates.count)
            groups = [(features, .equirectangular(longitude: longitude, latitude: latitude), frames[0])]
        }
        var regions: [MapRegion] = []
        var shapes: [MapShape] = []
        for group in groups where !group.features.isEmpty {
            // Fit the question areas; background such as Antarctica may run off the edge.
            let framed = group.features.filter { eligibleIDs.contains($0.id) }
            let points = (framed.isEmpty ? group.features : framed)
                .flatMap { $0.geometry.polygons.flatMap { $0.flatMap { $0.map(group.projection.forward) } } }
            let x = points.map(\.x), y = points.map(\.y)
            let bounds = CGRect(x: x.min()!, y: y.min()!, width: x.max()! - x.min()!, height: y.max()! - y.min()!)
            let region = MapRegion(projection: group.projection, bounds: bounds, frame: group.frame)
            let regionIndex = regions.count
            regions.append(region)
            for feature in group.features {
                let path = CGMutablePath()
                let previewPath = CGMutablePath()
                var largestRing: [CGPoint] = []
                var largestArea: CGFloat = 0
                for polygon in feature.geometry.polygons {
                    for (index, ring) in polygon.enumerated() {
                        let points = ring.map(region.point)
                        path.addLines(between: points)
                        path.closeSubpath()
                        // Preview canvases are at most 150 points high. This
                        // prepared-map tolerance is below one screen pixel there.
                        previewPath.addLines(between: Self.simplifiedRing(points, tolerance: 0.8))
                        previewPath.closeSubpath()
                        let area = abs(Self.signedArea(points))
                        if index == 0 && area > largestArea { largestRing = points; largestArea = area }
                    }
                }
                let anchor = Self.interiorPoint(path: path, ring: largestRing)
                shapes.append(MapShape(id: feature.id, path: path, previewPath: previewPath, anchor: anchor, region: regionIndex,
                                       bounds: path.boundingBoxOfPath, transform: .identity))
            }
        }
        self.regions = regions
        self.shapes = shapes
        callouts = Self.callouts(ids: smallIDs, size: size)
    }

    private static func simplifiedRing(_ points: [CGPoint], tolerance: CGFloat) -> [CGPoint] {
        guard points.count > 3 else { return points }
        var keep = Set([0, points.count - 1])
        var ranges = [(0, points.count - 1)]
        while let (start, end) = ranges.popLast() {
            guard end > start + 1 else { continue }
            let a = points[start], b = points[end]
            let dx = b.x - a.x, dy = b.y - a.y
            let lengthSquared = dx * dx + dy * dy
            var farthest = start
            var maxDistanceSquared = tolerance * tolerance
            for index in (start + 1)..<end {
                let point = points[index]
                let fraction = lengthSquared == 0 ? 0 : max(0, min(1,
                    ((point.x - a.x) * dx + (point.y - a.y) * dy) / lengthSquared))
                let x = point.x - a.x - fraction * dx
                let y = point.y - a.y - fraction * dy
                let distanceSquared = x * x + y * y
                if distanceSquared > maxDistanceSquared {
                    maxDistanceSquared = distanceSquared
                    farthest = index
                }
            }
            if farthest != start {
                keep.insert(farthest)
                ranges.append((start, farthest))
                ranges.append((farthest, end))
            }
        }
        return keep.sorted().map { points[$0] }
    }

    private static func frames(size: CGSize, us: Bool, hasCallouts: Bool) -> [CGRect] {
        let usableWidth = size.width - (hasCallouts ? 70 : 24)
        if us {
            return [
                CGRect(x: 12, y: 12, width: usableWidth, height: size.height * 0.71),
                CGRect(x: 16, y: size.height * 0.76, width: size.width * 0.40, height: size.height * 0.20),
                CGRect(x: size.width * 0.47, y: size.height * 0.79, width: size.width * 0.25, height: size.height * 0.14)
            ]
        }
        return [CGRect(x: 12, y: 16, width: usableWidth, height: size.height - 32)]
    }

    private static func callouts(ids smallIDs: [String], size: CGSize) -> [MapCallout] {
        // Markers stay above the 44-point zoom row (plus its 10-point margin) at the bottom edge.
        let lane = size.height - 54
        let spacing: CGFloat = max(44, min(62, (lane - 48) / CGFloat(max(1, smallIDs.count))))
        let firstCenter = min(size.height * 0.20, max(22, lane - 22 - CGFloat(max(0, smallIDs.count - 1)) * spacing))
        return smallIDs.enumerated().map { index, id in
            MapCallout(id: id, number: index + 1,
                       center: CGPoint(x: size.width - 27, y: firstCenter + CGFloat(index) * spacing))
        }
    }

    func hit(_ screen: CGPoint, viewport: MapViewport, tolerance: CGFloat = 3) -> MapHit {
        if let callout = callouts.first(where: { $0.frame.contains(screen) }) { return .area(callout.id) }
        let point = viewport.map(screen, size: size)
        guard let shape = shapes.first(where: { $0.contains(point) }) else { return .water }
        guard eligibleIDs.contains(shape.id) else { return .water }
        // Reject a tap near another eligible area instead of recording an uncertain answer.
        let delta = tolerance / viewport.scale
        for offset in [CGPoint(x: delta, y: 0), CGPoint(x: -delta, y: 0), CGPoint(x: 0, y: delta), CGPoint(x: 0, y: -delta)] {
            let neighbor = CGPoint(x: point.x + offset.x, y: point.y + offset.y)
            if shapes.contains(where: { $0.id != shape.id && eligibleIDs.contains($0.id) && $0.contains(neighbor) }) {
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
        guard let shape = shapes.first(where: { $0.contains(point) }) else { return nil }
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
