import Testing
import Foundation
import CoreGraphics
import UIKit
@testable import Atlas

@Test func allCatalogPacksResolveAndDecode() throws {
    let library = try MapLibrary()
    #expect(library.catalog.maps.count == 12)
    for entry in library.catalog.maps {
        let pack = try library.load(entry.id)
        #expect(pack.areas.count == entry.areaCount)
        #expect(Set(pack.features.map(\.id)).isSuperset(of: Set(pack.areas.map(\.id))))
    }
    #expect(throws: (any Error).self) { try library.load("missing") }
}

@Test func projectionRoundTripsIncludingAntimeridian() {
    let cases: [(MapProjection, Coordinate)] = [
        (.albers, Coordinate(-105, 39)), (.albers, Coordinate(-70, 44)),
        (.equirectangular(longitude: -154, latitude: 64), Coordinate(179.7, 51.8)),
        (.equirectangular(longitude: -154, latitude: 64), Coordinate(-150, 64)),
        (.equirectangular(longitude: -157, latitude: 20), Coordinate(-155.5, 19.7)),
        (.equirectangular(longitude: 10, latitude: 51), Coordinate(13.4, 52.5))
    ]
    for (projection, coordinate) in cases {
        let result = projection.inverse(projection.forward(coordinate))
        #expect(abs(coordinate.latitude - result.latitude) < 1e-8)
        #expect(abs(coordinate.longitude - result.longitude) < 1e-8)
    }
}

@Test func geographicHitsAndInverseSurviveZoomPanAndResize() throws {
    let library = try MapLibrary()
    let cases: [(String, String, Coordinate)] = [
        ("us-states", "US-CO", Coordinate(-105.5, 39)),
        ("us-states", "US-AK", Coordinate(-150, 64)),
        ("us-states", "US-HI", Coordinate(-155.55, 19.65)),
        ("us-states", "US-RI", Coordinate(-71.5, 41.7)),
        ("us-states", "US-DE", Coordinate(-75.5, 39)),
        ("germany-states", "DE-BY", Coordinate(11.5, 48.7)),
        ("nyc-boroughs", "NYC-BORO-1", Coordinate(-73.965, 40.78)),
        ("nyc-boroughs", "NYC-BORO-5", Coordinate(-74.15, 40.58)),
        ("nyc-neighborhoods-focused", "NYC-BORO-5", Coordinate(-74.15, 40.58)),
        ("nyc-neighborhoods-focused", "NYC-BORO-2", Coordinate(-73.88, 40.85)),
        ("nyc-neighborhoods-focused", "NYC-PRACTICE-WEST-BROOKLYN", Coordinate(-73.98, 40.67)),
        ("nyc-neighborhoods-focused", "NYC-PRACTICE-SOUTH-EAST-BROOKLYN", Coordinate(-73.97, 40.59)),
        ("nyc-neighborhoods-focused", "NYC-PRACTICE-OTHER-QUEENS", Coordinate(-73.82, 40.73)),
        ("nyc-neighborhoods-focused", "http://nyc.pediacities.com/Resource/Neighborhood/DUMBO", Coordinate(-73.989, 40.703)),
        ("nyc-neighborhoods-focused", "http://nyc.pediacities.com/Resource/Neighborhood/Long_Island_City", Coordinate(-73.948, 40.744))
    ]
    for (map, id, coordinate) in cases {
        let pack = try library.load(map)
        for size in [CGSize(width: 360, height: 380), CGSize(width: 780, height: 320)] {
            let layout = MapLayout(pack: pack, size: size)
            for viewport in [MapViewport(), MapViewport(scale: 3, offset: CGSize(width: 15, height: -30))] {
                let screen = try #require(layout.screen(coordinate, areaID: id, viewport: viewport))
                #expect(layout.hit(screen, viewport: viewport, tolerance: 0) == .area(id))
                let back = try #require(layout.coordinate(screen, viewport: viewport))
                #expect(abs(back.longitude - coordinate.longitude) < 1e-8)
                #expect(abs(back.latitude - coordinate.latitude) < 1e-8)
            }
        }
    }
}

@Test func allFiftyStatesHaveGeometryAndCalloutsHaveRealAnchors() throws {
    let pack = try MapLibrary().load("us-states")
    let layout = MapLayout(pack: pack, size: CGSize(width: 360, height: 400))
    #expect(pack.areas.count == 50)
    #expect(layout.shapes.count == 51)
    for area in pack.areas {
        let shape = try #require(layout.shapes.first { $0.id == area.id })
        #expect(shape.path.contains(shape.anchor, using: .evenOdd))
    }
    for callout in layout.callouts {
        #expect(callout.frame.width >= 44)
        #expect(layout.hit(callout.center, viewport: MapViewport()) == .area(callout.id))
    }
    #expect(layout.callouts.contains { $0.id == "US-DE" })
    #expect(layout.callouts.contains { $0.id == "US-RI" })
    let dc = try #require(layout.shapes.first { $0.id == "US-DC" })
    #expect(layout.hit(dc.anchor, viewport: MapViewport(), tolerance: 0) == .water)
}

@Test func holesWaterBackgroundAndBordersDoNotSubmitAnswers() throws {
    let manifest = try JSONDecoder().decode(MapManifest.self, from: Data("""
    {"schemaVersion":2,"id":"fixture","name":"Fixture","areaType":"area","coordinateSystem":"OGC:CRS84","geometryAsset":"areas.geojson","areas":[{"id":"A","name":"A"},{"id":"B","name":"B"}]}
    """.utf8))
    let features = try JSONDecoder().decode(FeatureCollection.self, from: Data("""
    {"features":[
    {"id":"A","geometry":{"type":"Polygon","coordinates":[[[0,0],[10,0],[10,10],[0,10],[0,0]],[[3,3],[3,7],[7,7],[7,3],[3,3]]]}},
    {"id":"B","geometry":{"type":"Polygon","coordinates":[[[10,0],[20,0],[20,10],[10,10],[10,0]]]}},
    {"id":"background","geometry":{"type":"Polygon","coordinates":[[[20,0],[30,0],[30,10],[20,10],[20,0]]]}}
    ]}
    """.utf8)).features
    let layout = MapLayout(pack: MapPack(manifest: manifest, features: features), size: CGSize(width: 600, height: 300))
    let viewport = MapViewport()
    func screen(_ x: Double, _ y: Double) -> CGPoint { layout.regions[0].point(Coordinate(x, y)) }
    #expect(layout.hit(screen(5, 5), viewport: viewport) == .water)
    #expect(layout.hit(screen(25, 5), viewport: viewport) == .water)
    #expect(layout.hit(screen(9.95, 5), viewport: viewport) == .ambiguous)
    #expect(layout.hit(screen(1, 5), viewport: viewport) == .area("A"))
    #expect(layout.coordinate(screen(5, 5), viewport: viewport) == nil)
}

@Test func pinchAnchorStaysFixedAndResetRestoresIdentity() {
    let size = CGSize(width: 400, height: 400), anchor = CGPoint(x: 90, y: 130)
    var viewport = MapViewport()
    viewport.zoom(to: 3, anchor: anchor, size: size)
    #expect(viewport.screen(anchor, size: size) == anchor)
    viewport.zoom(to: 0.5, anchor: anchor, size: size)
    #expect(viewport == MapViewport())
}

@Test func missedAnswersAreSpacedAndFirstAttemptsStaySeparate() {
    let areas = (1...6).map { Area(id: "\($0)", name: "Area \($0)") }
    var session = PracticeSession(areas: areas, mode: .find, ordered: true)
    session.submit(areas[1])
    session.submit(areas[0]) // A second tap must not change the recorded answer.
    #expect(session.firstAttemptCorrect == 0)
    #expect(session.questions.count == 7)
    #expect(session.questions[3].isReview)
    #expect(session.questions[3].area == areas[0])
    session.advance()
    while let question = session.current {
        session.submit(question.area)
        session.advance()
    }
    #expect(session.firstAttemptCorrect == 5)
    #expect(session.reviewedCorrect == 1)
    #expect(session.primaryCount == 6)
    #expect(session.missed == [areas[0]])
}

@Test func showAnswerCannotCreateAnEndlessReviewLoop() {
    let areas = [Area(id: "a", name: "A"), Area(id: "b", name: "B")]
    var session = PracticeSession(areas: areas, mode: .name, ordered: true)
    while !session.isComplete { session.submit(nil); session.advance() }
    #expect(session.questions.count == 4)
    #expect(session.firstAttemptCorrect == 0)
    #expect(session.reviewedCorrect == 0)
    #expect(session.questions.allSatisfy { $0.choices.contains($0.area) && Set($0.choices).count == $0.choices.count })
}

@MainActor
@Test func progressPersistsAndKeepsMapsAndModesSeparate() throws {
    let suite = "AtlasTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = ProgressStore(defaults: defaults)
    let area = Area(id: "a", name: "A")
    var session = PracticeSession(areas: [area], mode: .find)
    store.save(session, map: "us-states")
    #expect(store.record(for: "us-states", mode: .find).sessions == 0)
    session.submit(area); session.advance()
    store.save(session, map: "us-states")
    let restored = ProgressStore(defaults: defaults)
    #expect(restored.record(for: "us-states", mode: .find).firstCorrect == 1)
    #expect(restored.record(for: "us-states", mode: .name).sessions == 0)
    #expect(restored.record(for: "germany-states", mode: .find).sessions == 0)
}

@Test func learningContentIsCompleteAndFlagsDecode() throws {
    let content = try LearningContent.load()
    let library = try MapLibrary()
    for (id, count) in [("us-states", 50), ("germany-states", 16)] {
        let pack = try library.load(id)
        let states = content.states(in: pack)
        #expect(states.count == count)
        #expect(Set(states.map(\.id)) == Set(pack.areas.map(\.id)))
        for state in states {
            #expect(!state.capital.isEmpty && !state.nickname.isEmpty && !state.flagCredit.isEmpty)
            let image = try #require(LearningContent.flag(state))
            #expect(image.size.width >= 300 && image.size.height >= 100)
        }
    }
    #expect(content.state("US-CA")?.capital == "Sacramento")
    #expect(content.state("DE-BY")?.capital == "München")
    #expect(content.state("DE-BE")?.capital == "Berlin")
    #expect(content.state("DE-HH")?.capital == "Hamburg")
    #expect(content.state("US-MN")?.flagLicense.isEmpty == false)
}

@Test func cityPopulationsHaveConsistentDatedRankings() throws {
    let content = try LearningContent.load()
    for (country, count, date) in [("US", 50, "2025-07-01"), ("DE", 10, "2024-12-31")] {
        let cities = content.cities.filter { $0.country == country }
        #expect(cities.count == count)
        #expect(cities.map(\.rank) == Array(1...count).map(Optional.some))
        #expect(cities.allSatisfy { $0.populationDate == date && ($0.population ?? 0) > 0 })
        #expect(zip(cities, cities.dropFirst()).allSatisfy { $0.population! > $1.population! })
    }
    #expect(content.cities.first?.population == 8_584_629)
    #expect(content.cities.first { $0.name == "Berlin" }?.population == 3_685_265)
    #expect(content.landmarks.filter { $0.country == "US" }.count == 50)
    #expect(content.landmarks.filter { $0.country == "DE" }.count == 20)
    #expect(Set((content.cities + content.landmarks).map(\.id)).count == 130)
}

@Test func everyModeHasUsableQuestionsAndUniqueAnswerLabels() throws {
    let content = try LearningContent.load()
    for id in ["us-states", "germany-states", "nyc-neighborhoods-focused"] {
        let pack = try MapLibrary().load(id)
        for mode in PracticeMode.available(in: pack) {
            let areas = content.areas(in: pack, mode: mode)
            #expect(!areas.isEmpty)
            let session = PracticeSession(areas: areas, mode: mode)
            for question in session.questions {
                #expect(question.choices.contains(question.area))
                let labels = question.choices.map { content.answerLabel($0, mode: mode) }
                #expect(Set(labels).count == labels.count)
                #expect(!content.prompt(question.area, mode: mode, areaType: pack.manifest.areaType).isEmpty)
            }
        }
    }
}

@Test func allLearningLocationsRoundTripThroughCorrectInsets() throws {
    let content = try LearningContent.load()
    for id in ["us-states", "germany-states"] {
        let pack = try MapLibrary().load(id)
        for size in [CGSize(width: 360, height: 360), CGSize(width: 780, height: 320)] {
            let layout = MapLayout(pack: pack, size: size)
            for mode in [PracticeMode.cityLocation, .capitalLocation, .landmarkLocation] {
                for area in content.areas(in: pack, mode: mode) {
                    let target = try #require(content.location(area, mode: mode))
                    let viewport = MapViewport(scale: 3, offset: CGSize(width: 12, height: -31))
                    let screen = try #require(layout.screen(target.coordinate, areaID: target.regionID, viewport: viewport))
                    let result = try #require(layout.locationPin(screen, viewport: viewport), "Cannot place \(area.name)")
                    #expect(result.coordinate.distanceKM(to: target.coordinate) < 0.001)
                }
            }
        }
    }
}

@Test func pointQuestionsAcceptWaterButRejectInsetGaps() throws {
    let pack = try MapLibrary().load("us-states")
    let layout = MapLayout(pack: pack, size: CGSize(width: 400, height: 400))
    let water = Coordinate(-74.5, 37)
    let point = try #require(layout.screen(water, areaID: "US-NY", viewport: MapViewport()))
    #expect(layout.coordinate(point, viewport: MapViewport()) == nil)
    #expect(layout.locationPin(point, viewport: MapViewport()) != nil)
    #expect(layout.locationPin(CGPoint(x: 220, y: 301), viewport: MapViewport()) == nil)
}

@Test func locationDistanceUsesEarthCoordinatesAndRecordsOnlyOnce() throws {
    #expect(abs(Coordinate(0, 0).distanceKM(to: Coordinate(1, 0)) - 111.195) < 0.01)
    #expect(Coordinate(179.9, 0).distanceKM(to: Coordinate(-179.9, 0)) < 23)
    #expect(Coordinate(-74, 40).distanceKM(to: Coordinate(13, 52)) > 6000)
    let area = Area(id: "statue", name: "Statue of Liberty")
    let target = MapPin(coordinate: Coordinate(-74.04443, 40.68921), regionID: "US-NY")
    var session = PracticeSession(areas: [area], mode: .landmarkLocation)
    session.submitLocation(target, target: target, toleranceKM: 50)
    session.expire()
    #expect(session.answer?.correct == true)
    #expect(session.answer?.distanceKM == 0)
    #expect(session.firstAttemptCorrect == 1)
    var missed = PracticeSession(areas: [area], mode: .landmarkLocation)
    missed.submitLocation(MapPin(coordinate: Coordinate(-150, 64), regionID: "US-AK"), target: target, toleranceKM: 50)
    #expect(missed.answer?.correct == false)
    #expect(missed.questions.count == 2)
}

@Test func timerPausesResumesAndExpiresWithoutDoubleScoring() {
    var timer = QuestionTimer(seconds: 30)
    timer.resume(now: 100)
    timer.tick(now: 108)
    #expect(timer.remaining == 22)
    timer.pause(now: 110)
    timer.tick(now: 500)
    #expect(timer.remaining == 20)
    timer.resume(now: 500)
    timer.tick(now: 519)
    #expect(!timer.expired && timer.remaining == 1)
    timer.tick(now: 530)
    #expect(timer.expired && timer.remaining == 0)
    let area = Area(id: "a", name: "A")
    var session = PracticeSession(areas: [area], mode: .capital, secondsAllowed: 30)
    session.expire(); session.expire(); session.submit(area)
    #expect(session.questions.count == 2 && session.firstAttemptCorrect == 0)
    #expect(session.answer?.timedOut == true)
    session.advance(); session.expire(); session.advance()
    #expect(session.isComplete && session.questions.count == 2)
}

@MainActor
@Test func timerSettingsKeepSeparateProgress() throws {
    let suite = "AtlasTimerTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = ProgressStore(defaults: defaults)
    let area = Area(id: "US-AL", name: "Alabama")
    var session = PracticeSession(areas: [area], mode: .capital, secondsAllowed: 30)
    session.submit(area); session.advance(); store.save(session, map: "us-states")
    #expect(store.record(for: "us-states", mode: .capital, secondsAllowed: 30).sessions == 1)
    #expect(store.record(for: "us-states", mode: .capital).sessions == 0)
    #expect(store.record(for: "us-states", mode: .flag, secondsAllowed: 30).sessions == 0)
}

@Test func requestedNYCNeighborhoodsArePlayable() throws {
    let pack = try MapLibrary().load("nyc-neighborhoods-focused")
    #expect(pack.areas.count == 47)
    for name in ["Chinatown", "Nolita", "Tribeca", "Financial District", "Bed-Stuy", "DUMBO", "Williamsburg", "Greenpoint", "Long Island City", "West Brooklyn", "South & East Brooklyn", "Queens (other areas)", "The Bronx", "Staten Island"] {
        #expect(pack.areas.contains { $0.name == name })
    }
    #expect(!pack.areas.contains { ["Country Club", "Marine Park", "Allerton"].contains($0.name) })
    #expect(MapLibrary.starterIDs.contains(pack.id))
    #expect(!MapLibrary.starterIDs.contains("nyc-local-neighborhoods"))
}


@MainActor
@Test func mapWorkloadBenchmark() throws {
    for id in MapLibrary.starterIDs {
        let start = Date.timeIntervalSinceReferenceDate
        let pack = try MapLibrary().load(id)
        let loadMS = (Date.timeIntervalSinceReferenceDate - start) * 1000
        var layoutMS = 0.0
        for _ in 0..<5 {
            let start = Date.timeIntervalSinceReferenceDate
            _ = MapLayout(pack: pack, size: CGSize(width: 360, height: 380))
            layoutMS += (Date.timeIntervalSinceReferenceDate - start) * 1000 / 5
        }
        let view = GeographicMapView(pack: pack)
        view.frame = CGRect(x: 0, y: 0, width: 360, height: 380)
        view.layoutIfNeeded()
        let renderer = UIGraphicsImageRenderer(size: view.bounds.size)
        let drawStart = Date.timeIntervalSinceReferenceDate
        for step in 0..<30 {
            view.viewport = MapViewport(scale: 2, offset: CGSize(width: step, height: 0))
            // The vector layers are rendered by Core Animation. Measure app-side
            // viewport and annotation work, excluding the GPU compositor.
            _ = renderer.image { _ in view.subviews.first?.draw(view.bounds) }
            CATransaction.flush()
        }
        let drawMS = (Date.timeIntervalSinceReferenceDate - drawStart) * 1000 / 30
        print("MAP_BENCH \(id) load_ms=\(loadMS) layout_ms=\(layoutMS) cpu_update_ms=\(drawMS)")
    }
}

@Test func greatLakesAreWaterAndIllinoisKeepsItsShoreline() throws {
    let pack = try MapLibrary().load("us-states")
    for size in [CGSize(width: 360, height: 380), CGSize(width: 780, height: 320)] {
        let layout = MapLayout(pack: pack, size: size)
        for viewport in [MapViewport(), MapViewport(scale: 4, offset: CGSize(width: 12, height: -30))] {
            for coordinate in [Coordinate(-87, 47.5), Coordinate(-87, 43.5), Coordinate(-82.7, 44.5),
                               Coordinate(-81.2, 42.1), Coordinate(-77.8, 43.5), Coordinate(-87.55, 41.9)] {
                let screen = try #require(layout.screen(coordinate, areaID: "US-IL", viewport: viewport))
                #expect(layout.hit(screen, viewport: viewport, tolerance: 0) == .water)
                #expect(layout.coordinate(screen, viewport: viewport) == nil)
                #expect(layout.locationPin(screen, viewport: viewport) != nil)
            }
            for (id, coordinate) in [("US-IL", Coordinate(-87.65, 41.9)),
                                     ("US-MI", Coordinate(-83.1, 42.4)), ("US-MI", Coordinate(-87.4, 46.5))] {
                let screen = try #require(layout.screen(coordinate, areaID: id, viewport: viewport))
                #expect(layout.hit(screen, viewport: viewport, tolerance: 0) == .area(id))
            }
        }
    }
}

@MainActor
@Test func mapLayersReusePathsAndMatchGeographicTransforms() throws {
    let view = GeographicMapView(pack: try MapLibrary().load("us-states"))
    view.frame = CGRect(x: 0, y: 0, width: 360, height: 380)
    view.layoutIfNeeded()
    let layout = try #require(view.layout)
    let geography = try #require(view.layer.sublayers?.first)
    let layers = try #require(geography.sublayers)
    #expect(layers.count == 52) // 51 areas and one highlight outline.
    let paths = layers.compactMap { ($0 as? CAShapeLayer)?.path }
    for step in 1...30 {
        view.applyViewport(MapViewport(scale: 2, offset: CGSize(width: step, height: -12)))
        view.highlight = step.isMultiple(of: 2) ? "US-IL" : "US-MI"
        view.setNeedsLayout()
        view.layoutIfNeeded()
        for (index, shape) in layout.shapes.enumerated() {
            #expect((geography.sublayers?[index] as? CAShapeLayer)?.path === paths[index])
            let actual = shape.anchor.applying(geography.affineTransform())
            let expected = view.viewport.screen(shape.anchor, size: layout.size)
            #expect(abs(actual.x - expected.x) < 1e-8 && abs(actual.y - expected.y) < 1e-8)
        }
    }
    view.frame.size = CGSize(width: 780, height: 320)
    view.layoutIfNeeded()
    #expect(view.layout?.size == view.bounds.size)
    #expect((geography.sublayers?.first as? CAShapeLayer)?.path !== paths[0])
}
