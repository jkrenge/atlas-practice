import Foundation
import UIKit

struct StateFact: Sendable, Decodable, Identifiable {
    let id: String
    let name: String
    let capital: String
    let capitalCoordinate: Coordinate
    let nickname: String
    let nicknameKind: String
    let nicknameSource: URL
    let sourceURL: URL
    let flagAsset: String
    let flagCredit: String
    let flagSource: URL
    let flagLicense: String
}

struct PlaceFact: Sendable, Decodable, Identifiable {
    let id: String
    let name: String
    let country: String
    let stateID: String
    let coordinate: Coordinate
    let sourceURL: URL
    let population: Int?
    let populationDate: String?
    let populationDefinition: String?
    let rank: Int?
    let pointDefinition: String?
    var area: Area { Area(id: id, name: name) }
    var populationLabel: String { population?.formatted(.number.locale(Locale(identifier: "en_US"))) ?? "" }
}

struct LearningContent: Sendable, Decodable {
    let schemaVersion: Int
    let states: [StateFact]
    let cities: [PlaceFact]
    let landmarks: [PlaceFact]

    static func load(bundle: Bundle = .main) throws -> LearningContent {
        guard let url = bundle.resourceURL?.appendingPathComponent("content/learning.json") else {
            throw MapLoadError.invalid("The learning content is missing.")
        }
        let data = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
        guard data.schemaVersion == 1, data.states.count == 66, data.cities.count == 60, data.landmarks.count == 70 else {
            throw MapLoadError.invalid("The learning content is incomplete.")
        }
        return data
    }
    func states(in pack: MapPack) -> [StateFact] { states.filter { pack.area($0.id) != nil } }
    func country(_ pack: MapPack) -> String { pack.id == "us-states" ? "US" : "DE" }
    func places(in pack: MapPack, landmarks: Bool) -> [PlaceFact] {
        (landmarks ? self.landmarks : cities).filter { $0.country == country(pack) }
    }
    func state(_ id: String) -> StateFact? { states.first { $0.id == id } }
    func place(_ id: String) -> PlaceFact? { cities.first { $0.id == id } ?? landmarks.first { $0.id == id } }
    func areas(in pack: MapPack, mode: PracticeMode) -> [Area] {
        switch mode {
        case .cityLocation, .population: places(in: pack, landmarks: false).map(\.area)
        case .landmarkLocation: places(in: pack, landmarks: true).map(\.area)
        default: pack.areas
        }
    }
    func answerLabel(_ area: Area, mode: PracticeMode) -> String {
        switch mode {
        case .capital: state(area.id)?.capital ?? area.name
        case .population: place(area.id)?.populationLabel ?? area.name
        default: area.name
        }
    }
    func location(_ area: Area, mode: PracticeMode) -> MapPin? {
        if mode == .capitalLocation, let state = state(area.id) {
            return MapPin(coordinate: state.capitalCoordinate, regionID: state.id)
        }
        if let place = place(area.id) { return MapPin(coordinate: place.coordinate, regionID: place.stateID) }
        return nil
    }
    func prompt(_ area: Area, mode: PracticeMode, areaType: String) -> String {
        switch mode {
        case .find: "Find \(area.name)"
        case .name: "Which \(areaType) is this?"
        case .capital: "What is the capital of \(area.name)?"
        case .flag: "Which state has this flag?"
        case .nickname: "Which state uses this name or slogan?"
        case .cityLocation, .landmarkLocation: "Locate \(area.name)"
        case .capitalLocation: "Locate \(state(area.id)?.capital ?? area.name)"
        case .population: "How many people live in \(area.name)?"
        }
    }
    static func flag(_ state: StateFact, bundle: Bundle = .main) -> UIImage? {
        guard !state.flagAsset.contains(".."), !state.flagAsset.hasPrefix("/") else { return nil }
        return UIImage(named: "content/" + state.flagAsset, in: bundle, compatibleWith: nil)
    }
}

struct MapPin: Equatable {
    let coordinate: Coordinate
    let regionID: String
}

extension Coordinate {
    func distanceKM(to other: Coordinate) -> Double {
        let radians = Double.pi / 180
        let a = pow(sin((other.latitude - latitude) * radians / 2), 2)
            + cos(latitude * radians) * cos(other.latitude * radians)
            * pow(sin((other.longitude - longitude) * radians / 2), 2)
        return 6_371.0088 * 2 * asin(sqrt(min(1, max(0, a))))
    }
}
