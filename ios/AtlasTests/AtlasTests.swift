import SwiftUI
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
        ("nyc-neighborhoods-focused", "NYC-PRACTICE-WEST-BROOKLYN", Coordinate(-74.03, 40.63)),
        ("nyc-neighborhoods-focused", "http://nyc.pediacities.com/Resource/Neighborhood/Park_Slope", Coordinate(-73.98, 40.67)),
        ("nyc-neighborhoods-focused", "http://nyc.pediacities.com/Resource/Neighborhood/Prospect_Heights", Coordinate(-73.967, 40.677)),
        ("nyc-neighborhoods-focused", "http://nyc.pediacities.com/Resource/Neighborhood/Downtown_Brooklyn", Coordinate(-73.987, 40.693)),
        ("nyc-neighborhoods-focused", "http://nyc.pediacities.com/Resource/Neighborhood/Crown_Heights", Coordinate(-73.94, 40.67)),
        ("nyc-neighborhoods-focused", "http://nyc.pediacities.com/Resource/Neighborhood/Prospect_Park", Coordinate(-73.97, 40.66)),
        ("nyc-neighborhoods-focused", "NYC-PRACTICE-SEAPORT", Coordinate(-74.0036, 40.7064)),
        ("nyc-neighborhoods-focused", "http://nyc.pediacities.com/Resource/Neighborhood/Financial_District", Coordinate(-74.009, 40.706)),
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
        #expect(shape.contains(shape.anchor))
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

@Test func shortLandscapeKeepsSmallAreaCalloutsReachable() throws {
    let pack = try MapLibrary().load("us-states")
    let size = CGSize(width: 874, height: 180)
    let layout = MapLayout(pack: pack, size: size)
    for callout in layout.callouts {
        #expect(CGRect(origin: .zero, size: size).contains(callout.frame))
        #expect(layout.hit(callout.center, viewport: MapViewport()) == .area(callout.id))
    }
    for (first, second) in zip(layout.callouts, layout.callouts.dropFirst()) {
        #expect(first.frame.maxY <= second.frame.minY)
    }
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

@MainActor
@Test func summaryTotalsTimersAndModesPerMap() throws {
    let suite = "AtlasSummaryTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = ProgressStore(defaults: defaults)
    let area = Area(id: "US-AL", name: "Alabama")
    for (mode, seconds, map) in [(PracticeMode.find, 0, "us-states"), (.find, 30, "us-states"),
                                 (.flag, 0, "us-states"), (.find, 0, "germany-states")] {
        var session = PracticeSession(areas: [area], mode: mode, secondsAllowed: seconds)
        // A flag miss adds a review question; answer it too so the session completes.
        while !session.isComplete { session.submit(mode == .flag ? nil : area); session.advance() }
        store.save(session, map: map)
    }
    #expect(store.summary(for: "us-states", mode: .find).sessions == 2)
    #expect(store.summary(for: "us-states", mode: .find).accuracy == 1)
    #expect(store.summary(for: "us-states").firstTotal == 3)
    #expect(store.summary(for: "us-states").accuracy == 2.0 / 3)
    #expect(store.summary(for: "nyc-boroughs").accuracy == nil)
}

@Test func tornPaperIsStableAndStaysInside() {
    let rect = CGRect(x: 0, y: 0, width: 335, height: 120)
    let torn = TornPaper(edges: [.top, .bottom], seed: 7)
    #expect(torn.path(in: rect) == torn.path(in: rect))                                     // never jitters
    #expect(rect.insetBy(dx: -0.01, dy: -0.01).contains(torn.path(in: rect).boundingRect)) // bites go inward only
    #expect(TornPaper().path(in: rect).boundingRect == rect)                                // untorn = rectangle
}

@MainActor
@Test func resettingProgressForgetsEveryScoreOnThisDevice() throws {
    let suite = "reset-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set(try JSONEncoder().encode(["us-states.find": PracticeRecord(sessions: 1, firstCorrect: 3, firstTotal: 4)]),
                 forKey: "practiceProgress.v1")
    let store = ProgressStore(defaults: defaults)
    #expect(store.summary(for: "us-states").sessions == 1)
    store.reset()
    #expect(store.summary(for: "us-states").sessions == 0)
    #expect(ProgressStore(defaults: defaults).records.isEmpty)
}

@Test func atlasCamerasStayOnTheMap() {
    for camera in [AtlasCamera.home, .sources, .settings] + ["us-states", "germany-states", "nyc-boroughs"].map(AtlasCamera.pack) {
        let point = AtlasWorld.point(longitude: camera.longitude, latitude: camera.latitude)
        #expect(CGRect(origin: .zero, size: AtlasWorld.size).contains(point))
        #expect(camera.span > 0 && camera.span < 360)
    }
}

@Test func feedbackVoiceIsDeterministicAndTiered() {
    let pin = MapPin(coordinate: Coordinate(0, 0), regionID: "x")
    func line(_ answer: PracticeSession.Answer, review: Bool = false, streak: Int = 1) -> String {
        Voice.headline(for: answer, isReview: review, streak: streak, toleranceKM: 50, seed: 0)
    }
    #expect(line(.init(selected: nil, correct: true, guess: pin, distanceKM: 40)) == Voice.correct[0])
    #expect(line(.init(selected: nil, correct: false, guess: pin, distanceKM: 90)) == Voice.nearMiss[0])
    #expect(line(.init(selected: nil, correct: false, guess: pin, distanceKM: 900)) == Voice.farMiss[0])
    #expect(line(.init(selected: Area(id: "a", name: "A"), correct: false)) == Voice.wrong[0])
    #expect(line(.init(selected: nil, correct: false)) == Voice.shown[0])
    #expect(line(.init(selected: nil, correct: false, timedOut: true)) == Voice.timeout[0])
    #expect(line(.init(selected: nil, correct: true), review: true) == Voice.comeback[0])
    #expect(line(.init(selected: nil, correct: true), streak: 3) == Voice.streaks[3])
    #expect(line(.init(selected: nil, correct: true), review: true, streak: 3) == Voice.comeback[0])
    #expect(Voice.seed("US-WA") == 365)
    #expect(Voice.pick(Voice.correct, 7) == Voice.correct[1])
    #expect(Voice.pick(Voice.correct, -7) == Voice.correct[1])
    #expect(ResultRank(firstTry: 1) == .cartographer)
    #expect(ResultRank(firstTry: 0.8) == .navigator)
    #expect(ResultRank(firstTry: 0.5) == .explorer)
    #expect(ResultRank(firstTry: 0.49) == .wanderer)
}

@Test func sessionStreakCountsConsecutiveCorrectAnswers() {
    let areas = (1...4).map { Area(id: "\($0)", name: "Area \($0)") }
    var session = PracticeSession(areas: areas, mode: .find, ordered: true)
    session.submit(areas[0]); #expect(session.streak == 1); session.advance()
    session.submit(areas[1]); #expect(session.streak == 2); session.advance()
    session.submit(nil); #expect(session.streak == 0)
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
    for id in MapLibrary.starterIDs {
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
                    let target = try #require(content.location(area, mode: mode, in: pack))
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
    #expect(pack.areas.count == 53)
    for name in ["Chinatown", "Nolita", "Tribeca", "Financial District", "Bed-Stuy", "DUMBO", "Williamsburg", "Greenpoint", "Park Slope", "Prospect Heights", "Downtown Brooklyn", "Crown Heights", "Prospect Park", "Seaport", "Long Island City", "West Brooklyn", "South & East Brooklyn", "Queens (other areas)", "The Bronx", "Staten Island"] {
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
            view.applyViewport(MapViewport(scale: 2, offset: CGSize(width: step, height: 0)))
            // Measure native viewport and annotation work. Compositor frame
            // time is measured separately from these CPU updates.
            _ = renderer.image { _ in view.subviews.last?.draw(view.bounds) }
            CATransaction.flush()
        }
        let drawMS = (Date.timeIntervalSinceReferenceDate - drawStart) * 1000 / 30
        print("MAP_BENCH \(id) load_ms=\(loadMS) layout_ms=\(layoutMS) cpu_update_ms=\(drawMS)")
        let resizeStart = Date.timeIntervalSinceReferenceDate
        for height in [650, 580, 620, 650, 580, 620] {
            view.frame.size = CGSize(width: 402, height: height)
            view.layoutIfNeeded()
            CATransaction.flush()
        }
        print("MAP_RESIZE \(id) cpu_ms=\((Date.timeIntervalSinceReferenceDate - resizeStart) * 1000 / 6)")
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
@Test(arguments: MapLibrary.starterIDs)
func previewGeometryAndRendering(_ id: String) throws {
    let pack = try MapLibrary().load(id)
    func elements(_ path: CGPath) -> Int {
        var count = 0
        path.applyWithBlock { _ in count += 1 }
        return count
    }
    let original = pack.preparedLayout.shapes.reduce(0) { $0 + elements($1.path) }
    let preview = pack.preparedLayout.shapes.reduce(0) { $0 + elements($1.previewPath) }
    #expect(preview <= original)
    let view = MapPreviewView(pack: pack)
    view.frame = CGRect(x: 0, y: 0, width: 360, height: 150)
    let start = Date()
    let image = UIGraphicsImageRenderer(size: view.bounds.size).image { context in
        view.layer.render(in: context.cgContext)
    }
    #expect(image.size == view.bounds.size)
    #expect(view.layer.sublayers?.isEmpty ?? true)
    print("PREVIEW \(id) elements=\(original)->\(preview) draw_ms=\(Date().timeIntervalSince(start) * 1000)")
}

@MainActor
@Test(arguments: MapLibrary.starterIDs)
func nativeMapReusesTilesAndKeepsTapCoordinatesAligned(_ id: String) throws {
    let view = GeographicMapView(pack: try MapLibrary().load(id))
    view.frame = CGRect(x: 0, y: 0, width: 360, height: 380)
    view.layoutIfNeeded()
    let scroll = try #require(view.subviews.first as? UIScrollView)
    let content = try #require(view.viewForZooming(in: scroll))
    let geography = try #require(content.subviews.first)
    let base = try #require(geography.layer.sublayers?.first as? CATiledLayer)
    #expect(base.bounds.size == view.bounds.size)
    #expect(base.levelsOfDetail == 6 && base.levelsOfDetailBias == 5)
    #expect(geography.layer.sublayers?.count == 3) // Cached tiles and two answer overlays.
    #expect(scroll.maximumZoomScale == 32)
    for step in 1...30 {
        view.applyViewport(MapViewport(scale: 2, offset: CGSize(width: step, height: -12)))
        view.highlight = view.pack.areas[step % 2].id
        view.setNeedsLayout()
        view.layoutIfNeeded()
        #expect(geography.layer.sublayers?.first === base)
        for shape in try #require(view.layout).shapes {
            let actual = geography.convert(shape.anchor, to: view)
            let expected = view.viewport.screen(shape.anchor, size: view.bounds.size)
            #expect(abs(actual.x - expected.x) < 1e-8 && abs(actual.y - expected.y) < 1e-8)
            #expect(shape.contains(shape.anchor))
        }
    }
    // Exercise UIScrollView's own delegate path, including gesture state readback.
    scroll.zoomScale = 4
    scroll.contentOffset.x += 20
    for shape in try #require(view.layout).shapes {
        let actual = geography.convert(shape.anchor, to: view)
        let expected = view.viewport.screen(shape.anchor, size: view.bounds.size)
        #expect(abs(actual.x - expected.x) < 1e-8 && abs(actual.y - expected.y) < 1e-8)
    }
    view.frame.size = CGSize(width: 780, height: 320)
    view.layoutIfNeeded()
    let resized = try #require(view.layout)
    #expect(resized.size == view.bounds.size)
    #expect(geography.layer.sublayers?.first !== base)
    #expect(geography.layer.sublayers?.first is CATiledLayer)
    for (index, shape) in resized.shapes.enumerated() {
        #expect(shape.path === view.pack.preparedLayout.shapes[index].path)
        let actual = geography.convert(shape.anchor, to: view)
        let expected = view.viewport.screen(shape.anchor, size: resized.size)
        #expect(abs(actual.x - expected.x) < 1e-8 && abs(actual.y - expected.y) < 1e-8)
    }
    view.applyViewport(MapViewport())
    #expect(view.viewport == MapViewport() && scroll.zoomScale == 1)
}

@Test func mappedLakesAndNYCRiversDoNotSelectAreas() throws {
    let probes: [(String, String, [Coordinate])] = [
        ("us-states", "US-UT", [Coordinate(-112.5, 41.1), Coordinate(-81, 26.9)]),
        ("germany-states", "DE-BW", [Coordinate(9.4, 47.62), Coordinate(12.7, 53.43), Coordinate(11.46, 53.7)]),
        ("nyc-boroughs", "NYC-BORO-1", [Coordinate(-73.965, 40.743), Coordinate(-74.015, 40.72)]),
        ("nyc-neighborhoods-focused", "NYC-BORO-5", [Coordinate(-73.965, 40.743), Coordinate(-74.015, 40.72),
            Coordinate(-73.99278510511897, 40.70465085326032), Coordinate(-73.95473150505875, 40.73979288426392)])
    ]
    for (mapID, regionID, coordinates) in probes {
        let pack = try MapLibrary().load(mapID)
        for size in [CGSize(width: 360, height: 380), CGSize(width: 780, height: 320)] {
            let layout = MapLayout(pack: pack, size: size)
            for viewport in [MapViewport(), MapViewport(scale: 4, offset: CGSize(width: 15, height: -30))] {
                for coordinate in coordinates {
                    let point = try #require(layout.screen(coordinate, areaID: regionID, viewport: viewport))
                    #expect(layout.hit(point, viewport: viewport, tolerance: 0) == .water)
                    #expect(layout.coordinate(point, viewport: viewport) == nil)
                    #expect(layout.locationPin(point, viewport: viewport) != nil)
                }
            }
        }
    }
}

@Test func everyPlayableAreaRetainsASelectableInteriorAfterShoreClipping() throws {
    for id in MapLibrary.starterIDs {
        let pack = try MapLibrary().load(id)
        for size in [CGSize(width: 360, height: 380), CGSize(width: 780, height: 320)] {
            let layout = MapLayout(pack: pack, size: size)
            for area in pack.areas {
                let shape = try #require(layout.shapes.first { $0.id == area.id })
                #expect(shape.contains(shape.anchor))
                for viewport in [MapViewport(), MapViewport(scale: 3, offset: CGSize(width: 15, height: -30))] {
                    let point = viewport.screen(shape.anchor, size: size)
                    #expect(layout.hit(point, viewport: viewport, tolerance: 0) == .area(area.id))
                }
            }
        }
    }
}

@Test func challengePointsRewardDistanceAndSpeed() {
    let points = PracticeSession.challengePoints
    #expect(points(0, 3000, 1) == 1000)
    #expect(points(0, 3000, 0) == 700)
    #expect(points(1500, 3000, 1) == 250)
    #expect(points(3000, 3000, 1) == 0 && points(9000, 3000, 1) == 0)
    #expect(points(100, 3000, 0.5) > points(200, 3000, 0.5) && points(100, 3000, 0.5) > points(100, 3000, 0.4))
}

@MainActor
@Test func challengeIsOnePassAndKeepsTheHighScore() throws {
    let areas = (1...20).map { Area(id: "\($0)", name: "\($0)") }
    let here = MapPin(coordinate: Coordinate(2.35, 48.86), regionID: "")
    func play(hits: Int) -> PracticeSession {
        var session = PracticeSession(areas: areas, mode: .challenge, count: PracticeMode.challengeCount, ordered: true)
        for index in 0..<PracticeMode.challengeCount {
            if index < hits { session.submitLocation(here, target: here, toleranceKM: 300, rangeKM: 3000, timeLeft: 1) }
            else { session.expire() }
            session.advance()
        }
        return session
    }
    let good = play(hits: 3), weak = play(hits: 1)
    #expect(good.isComplete && good.questions.count == 15) // A miss is not asked again.
    #expect(good.score == 3000 && good.firstAttemptCorrect == 3 && good.missed.count == 12)
    let suite = "AtlasTests.challenge.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    // Records saved before high scores existed still load.
    defaults.set(Data(#"{"world-countries.find":{"sessions":1,"firstCorrect":3,"firstTotal":4,"reviewCorrect":0,"reviewTotal":1}}"#.utf8),
                 forKey: "practiceProgress.v1")
    let store = ProgressStore(defaults: defaults)
    #expect(store.summary(for: "world-countries").sessions == 1 && store.summary(for: "world-countries").highScore == nil)
    store.save(good, map: "world-countries")
    store.save(weak, map: "world-countries")
    let saved = ProgressStore(defaults: defaults).summary(for: "world-countries", mode: .challenge)
    #expect(saved.highScore == 3000 && saved.sessions == 2 && saved.reviewTotal == 0)
    #expect(ProgressStore(defaults: defaults).summary(for: "world-countries").highScore == 3000)
}

@Test func challengePlacesCanBePinnedOnEveryMap() throws {
    let content = try LearningContent.load()
    for id in MapLibrary.starterIDs {
        let pack = try MapLibrary().load(id)
        #expect(PracticeMode.available(in: pack).contains(.challenge))
        let places = content.areas(in: pack, mode: .challenge)
        #expect(places.count >= PracticeMode.challengeCount && Set(places.map(\.id)).count == places.count)
        let size = CGSize(width: 390, height: 560)
        let layout = MapLayout(pack: pack, size: size)
        for area in places {
            let target = try #require(content.location(area, mode: .challenge, in: pack))
            let screen = try #require(layout.screen(target.coordinate, areaID: target.regionID, viewport: MapViewport()))
            #expect(CGRect(origin: .zero, size: size).contains(screen), "\(area.name) is off the map")
            let pin = try #require(layout.locationPin(screen, viewport: MapViewport()))
            #expect(pin.coordinate.distanceKM(to: target.coordinate) < 0.001)
        }
    }
}

@Test func worldMapFitsItsCountriesWithoutWrapping() throws {
    let pack = try MapLibrary().load("world-countries")
    #expect(pack.areas.count == 197 && pack.manifest.areaTypePlural == "countries")
    let layout = MapLayout(pack: pack, size: CGSize(width: 780, height: 400))
    let frame = layout.regions[0].frame
    for (name, coordinate) in [("France", Coordinate(2.35, 48.86)), ("Kazakhstan", Coordinate(71.4, 51.2)),
                               ("New Zealand", Coordinate(174.8, -41.3)), ("United States of America", Coordinate(-149.9, 61.2)),
                               ("Russia", Coordinate(-173, 64.5)), ("Fiji", Coordinate(178.4, -18.1))] {
        let area = try #require(pack.areas.first { $0.name == name })
        let point = try #require(layout.screen(coordinate, areaID: area.id, viewport: MapViewport()))
        #expect(frame.contains(point))
        #expect(layout.hit(point, viewport: MapViewport(), tolerance: 0) == .area(area.id), "\(name)")
    }
    // East is right of west all the way across: nothing is drawn through the antimeridian.
    let anyID = pack.areas[0].id
    let west = try #require(layout.screen(Coordinate(-179, 0), areaID: anyID, viewport: MapViewport()))
    let east = try #require(layout.screen(Coordinate(179, 0), areaID: anyID, viewport: MapViewport()))
    #expect(west.x < east.x && east.x - west.x > frame.width * 0.9)
    for shape in layout.shapes where layout.eligibleIDs.contains(shape.id) && !["Russia", "Fiji", "United States of America", "Kiribati", "New Zealand"].contains(pack.area(shape.id)?.name) {
        #expect(shape.bounds.width < frame.width / 2, "\(pack.area(shape.id)?.name ?? shape.id) spans the map")
    }
}
