import Foundation

struct MapCatalog: Decodable {
    let schemaVersion: Int
    let maps: [Entry]
    struct Entry: Decodable, Identifiable {
        let id: String
        let name: String
        let manifest: String
        let areaCount: Int
    }
}

struct Area: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let name: String
}

struct MapManifest: Decodable {
    let schemaVersion: Int
    let id: String
    let name: String
    let areaType: String
    let coordinateSystem: String
    let geometryAsset: String
    let areas: [Area]
}

struct Coordinate: Equatable, Decodable {
    let longitude: Double
    let latitude: Double
    init(_ longitude: Double, _ latitude: Double) {
        self.longitude = longitude
        self.latitude = latitude
    }
}

struct AreaGeometry: Decodable {
    // A polygon contains an outer ring followed by zero or more holes.
    let polygons: [[[Coordinate]]]
    enum CodingKeys: CodingKey { case type, coordinates }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let type = try values.decode(String.self, forKey: .type)
        let coordinates: [[[[Double]]]]
        switch type {
        case "Polygon": coordinates = [try values.decode([[[Double]]].self, forKey: .coordinates)]
        case "MultiPolygon": coordinates = try values.decode([[[[Double]]]].self, forKey: .coordinates)
        default: throw MapLoadError.invalid("Unsupported geometry: \(type)")
        }
        polygons = try coordinates.map { polygon in
            guard !polygon.isEmpty else { throw MapLoadError.invalid("Empty polygon") }
            return try polygon.map { ring in
                guard ring.count >= 4 else { throw MapLoadError.invalid("Incomplete polygon ring") }
                return try ring.map { pair in
                    guard pair.count >= 2, pair[0].isFinite, pair[1].isFinite,
                          (-180...180).contains(pair[0]), (-90...90).contains(pair[1]) else {
                        throw MapLoadError.invalid("Invalid geographic coordinate")
                    }
                    return Coordinate(pair[0], pair[1])
                }
            }
        }
    }
}

struct GeoFeature: Decodable {
    let id: String
    let geometry: AreaGeometry
}

struct FeatureCollection: Decodable { let features: [GeoFeature] }

struct MapPack: Identifiable {
    let manifest: MapManifest
    let features: [GeoFeature]
    var id: String { manifest.id }
    var areas: [Area] { manifest.areas }
    func area(_ id: String?) -> Area? { areas.first { $0.id == id } }
}

enum MapLoadError: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        switch self { case .invalid(let message): message }
    }
}

struct MapLibrary {
    let root: URL
    let catalog: MapCatalog
    static let starterIDs = ["us-states", "germany-states", "nyc-boroughs", "nyc-local-neighborhoods"]

    init(bundle: Bundle = .main) throws {
        guard let root = bundle.resourceURL?.appendingPathComponent("maps", isDirectory: true) else {
            throw MapLoadError.invalid("The bundled maps are missing.")
        }
        try self.init(root: root)
    }

    init(root: URL) throws {
        self.root = root.standardizedFileURL
        catalog = try JSONDecoder().decode(MapCatalog.self, from: Data(contentsOf: root.appendingPathComponent("catalog.json")))
        guard catalog.schemaVersion == 2 else { throw MapLoadError.invalid("Unsupported map catalog version") }
    }

    func load(_ id: String) throws -> MapPack {
        guard let entry = catalog.maps.first(where: { $0.id == id }) else {
            throw MapLoadError.invalid("Map not found: \(id)")
        }
        let manifestURL = try asset(entry.manifest, relativeTo: root)
        let manifest = try JSONDecoder().decode(MapManifest.self, from: Data(contentsOf: manifestURL))
        guard manifest.schemaVersion == 2, manifest.coordinateSystem == "OGC:CRS84",
              manifest.id == id, manifest.areas.count == entry.areaCount else {
            throw MapLoadError.invalid("The map manifest is inconsistent: \(id)")
        }
        let geometryURL = try asset(manifest.geometryAsset, relativeTo: manifestURL.deletingLastPathComponent())
        let features = try JSONDecoder().decode(FeatureCollection.self, from: Data(contentsOf: geometryURL)).features
        let ids = Set(features.map(\.id))
        guard ids.count == features.count, Set(manifest.areas.map(\.id)).count == manifest.areas.count,
              manifest.areas.allSatisfy({ ids.contains($0.id) }) else {
            throw MapLoadError.invalid("The map has missing or duplicate areas: \(id)")
        }
        return MapPack(manifest: manifest, features: features)
    }

    private func asset(_ path: String, relativeTo directory: URL) throws -> URL {
        let url = directory.appendingPathComponent(path).standardizedFileURL
        guard url.path.hasPrefix(root.path + "/") else {
            throw MapLoadError.invalid("A map asset is outside the bundled maps.")
        }
        return url
    }
}
