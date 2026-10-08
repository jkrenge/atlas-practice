import XCTest

@MainActor
final class AtlasUITests: XCTestCase {
    var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
    }
    func open(_ map: String, mode: String) {
        tap(app.buttons["map-\(map)"])
        tap(app.buttons["start-\(mode)"])
        XCTAssertTrue(app.staticTexts["questionPrompt"].waitForExistence(timeout: 5))
    }
    func tap(_ element: XCUIElement) {
        for _ in 0..<9 where !element.isHittable {
            // Scroll in the page margin; dragging on the map pans the map.
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.8))
            start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.3)))
        }
        XCTAssertTrue(element.isHittable)
        element.tap()
    }
    func testUSGameplayFramePerformance() throws {
        try measureGameplay("us-states")
    }
    func testNYCGameplayFramePerformance() throws {
        try measureGameplay("nyc-boroughs")
    }
    func testHomeScrollingAndNavigationPerformance() throws {
        guard #available(iOS 26.0, *) else { throw XCTSkip("Frame hitch metrics require iOS 26") }
        let options = XCTMeasureOptions()
        options.iterationCount = 2
        options.invocationOptions = [.manuallyStart, .manuallyStop]
        measure(metrics: [XCTHitchMetric(application: app), XCTCPUMetric(application: app)], options: options) {
            app.terminate()
            app.launch()
            XCTAssertTrue(app.buttons["map-us-states"].waitForExistence(timeout: 5))
            startMeasuring()
            for mapID in ["us-states", "germany-states", "nyc-boroughs", "nyc-neighborhoods-focused"] {
                app.scrollViews.firstMatch.swipeUp()
                app.scrollViews.firstMatch.swipeDown()
                tap(app.buttons["map-\(mapID)"])
                XCTAssertTrue(app.buttons["study-map"].waitForExistence(timeout: 5))
                app.navigationBars.buttons.firstMatch.tap()
                XCTAssertTrue(app.buttons["map-us-states"].waitForExistence(timeout: 5))
            }
            stopMeasuring()
        }
    }
    func testHomeScrollMovesContent() throws {
        guard app.frame.width < 600 else { throw XCTSkip("The complete library fits on an iPad") }
        let firstMap = app.buttons["map-us-states"]
        XCTAssertTrue(firstMap.waitForExistence(timeout: 5))
        let originalY = firstMap.frame.minY
        app.scrollViews.firstMatch.swipeUp()
        let scrolledY = firstMap.frame.minY
        XCTAssertLessThan(scrolledY, originalY - 10, "A home-screen swipe must move the content")
        app.scrollViews.firstMatch.swipeDown()
        XCTAssertGreaterThan(firstMap.frame.minY, scrolledY + 10)
        firstMap.tap()
        XCTAssertTrue(app.buttons["study-map"].waitForExistence(timeout: 5))
    }
    private func measureGameplay(_ mapID: String) throws {
        guard #available(iOS 26.0, *) else { throw XCTSkip("Frame hitch metrics require iOS 26") }
        let options = XCTMeasureOptions()
        options.iterationCount = 2
        options.invocationOptions = [.manuallyStart, .manuallyStop]
        measure(metrics: [XCTHitchMetric(application: app), XCTCPUMetric(application: app)], options: options) {
            app.terminate()
            app.launch()
            XCTAssertTrue(app.buttons["map-\(mapID)"].waitForExistence(timeout: 5))
            startMeasuring()
            open(mapID, mode: "name")
            let map = app.images["geographicMap"]
            for _ in 0..<3 {
                app.buttons["show-answer"].tap()
                XCTAssertTrue(app.staticTexts["answerFeedback"].firstMatch.exists)
                map.swipeLeft()
                map.swipeRight()
                map.pinch(withScale: 1.5, velocity: 1)
                app.buttons["Reset map"].tap()
                app.buttons["continue-session"].tap()
                XCTAssertTrue(app.staticTexts["questionPrompt"].isHittable)
            }
            stopMeasuring()
        }
    }
    func testPolygonTapsCalloutsAndGestures() {
        open("us-states", mode: "find")
        let map = app.images["geographicMap"]
        map.coordinate(withNormalizedOffset: CGVector(dx: 0.04, dy: 0.04)).tap()
        XCTAssertTrue(app.buttons["show-answer"].exists)
        app.buttons["Zoom in"].tap()
        XCTAssertEqual(map.value as? String, "150 percent zoom")
        map.swipeLeft()
        XCTAssertEqual(app.staticTexts["questionPrompt"].label, "Find Washington")
        XCTAssertTrue(app.buttons["show-answer"].exists)
        app.buttons["Reset map"].tap()
        map.pinch(withScale: 1.5, velocity: 1)
        XCTAssertNotEqual(map.value as? String, "100 percent zoom")
        XCTAssertTrue(app.buttons["show-answer"].exists)
        app.buttons["Reset map"].tap()
        map.coordinate(withNormalizedOffset: CGVector(dx: 0.13, dy: 0.23)).tap()
        XCTAssertTrue(app.staticTexts["answerFeedback"].firstMatch.label.contains("That's right."))
        app.buttons["Zoom in"].tap()
        XCTAssertEqual(map.value as? String, "150 percent zoom")
        tap(app.buttons["continue-session"])
        XCTAssertEqual(map.value as? String, "100 percent zoom")
        map.coordinate(withNormalizedOffset: CGVector(dx: 0.925, dy: 0.20)).tap()
        XCTAssertTrue(app.staticTexts["answerFeedback"].firstMatch.label.contains("You chose Rhode Island"))
    }
    func testFindCorrectAnswerAdvancesAfterThreeSeconds() {
        open("us-states", mode: "find")
        let floatingPrompt = app.staticTexts["map-questionPrompt"]
        XCTAssertEqual(floatingPrompt.label, "Find Washington")
        XCTAssertTrue(app.images["geographicMap"].frame.contains(floatingPrompt.frame))
        tap(app.buttons["Use area list"])
        let search = app.searchFields.firstMatch
        search.tap()
        search.typeText("Washington")
        tap(app.buttons["area-US-WA"])
        let answeredAt = Date()
        XCTAssertTrue(app.buttons["continue-session"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["answerFeedback"].firstMatch.label.contains("That's right."))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Correct answer with hidden labels and floating controls"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let nextQuestion = NSPredicate(format: "label == %@", "Find Idaho")
        expectation(for: nextQuestion, evaluatedWith: floatingPrompt)
        waitForExpectations(timeout: 5)
        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(answeredAt), 2.5)
        XCTAssertFalse(app.buttons["continue-session"].exists)
    }

    func testFindManualContinueCancelsAutomaticAdvance() {
        open("us-states", mode: "find")
        tap(app.buttons["Use area list"])
        let search = app.searchFields.firstMatch
        search.tap()
        search.typeText("Washington")
        tap(app.buttons["area-US-WA"])
        tap(app.buttons["continue-session"])
        tap(app.buttons["show-answer"])
        _ = XCTWaiter.wait(for: [], timeout: 3.5)
        XCTAssertEqual(app.staticTexts["questionPrompt"].label, "Find Idaho")
        XCTAssertTrue(app.buttons["continue-session"].exists)
    }

    func testContinueRemainsVisibleAndReturnsToQuestion() {
        open("us-states", mode: "find")
        tap(app.buttons["Use area list"])
        tap(app.buttons["area-US-AL"])
        let next = app.buttons["continue-session"]
        XCTAssertTrue(next.isHittable)
        XCTAssertTrue(app.frame.contains(next.frame), "Continue must be fully visible without scrolling")
        next.tap()
        let prompt = app.staticTexts["questionPrompt"]
        XCTAssertTrue(prompt.isHittable)
        XCTAssertTrue(app.frame.contains(prompt.frame))
    }
    func testSessionLengthChoices() {
        tap(app.buttons["map-us-states"])
        for (option, count) in [("25", 25), ("All", 50), ("10", 10)] {
            tap(app.buttons["session-length"])
            app.buttons[option].tap()
            if option == "25" {
                app.terminate()
                app.launch()
                tap(app.buttons["map-us-states"])
            }
            tap(app.buttons["start-find"])
            XCTAssertTrue(app.staticTexts["Question 1 of \(count)"].waitForExistence(timeout: 5))
            app.buttons["leave-practice"].tap()
        }
        app.terminate()
        app.launch()
        open("us-states", mode: "find")
        XCTAssertTrue(app.staticTexts["Question 1 of 10"].exists)
    }
    func testMapFillsPlayScreenAndFeedbackStaysVisible() {
        open("us-states", mode: "find")
        let map = app.images["geographicMap"]
        XCTAssertEqual(map.frame.width, app.frame.width, accuracy: 1)
        XCTAssertGreaterThan(map.frame.height, app.frame.height * 0.60)
        XCTAssertFalse(app.navigationBars["Find the area"].exists)
        app.buttons["Use area list"].tap()
        app.buttons["area-US-AL"].tap()
        XCTAssertTrue(app.frame.contains(app.staticTexts["answerFeedback"].firstMatch.frame))
        XCTAssertTrue(app.frame.contains(app.buttons["continue-session"].frame))
        app.buttons["continue-session"].tap()
        XCTAssertTrue(app.staticTexts["questionPrompt"].isHittable)
        app.buttons["leave-practice"].tap()
        XCTAssertTrue(app.buttons["start-find"].waitForExistence(timeout: 5))
    }
    func testNativePanKeepsTapCoordinatesAligned() {
        open("us-states", mode: "find")
        let map = app.images["geographicMap"]
        let start = map.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = map.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.65))
        // Stop before release so UIScrollView momentum does not move the tap target.
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.3)
        // Washington moves with the map. This point is outside Washington
        // before the drag, so it also detects a gesture that fails to pan.
        map.coordinate(withNormalizedOffset: CGVector(dx: 0.28, dy: 0.38)).tap()
        XCTAssertTrue(app.staticTexts["answerFeedback"].firstMatch.label.contains("That's right."))
    }
    func testNameModeCorrectWrongAndReveal() {
        open("us-states", mode: "name")
        tap(app.buttons["choice-US-WA"])
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "That's right.")).firstMatch.exists)
        tap(app.buttons["continue-session"])
        tap(app.buttons["choice-US-WA"])
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "You chose Washington")).firstMatch.exists)
        tap(app.buttons["continue-session"])
        tap(app.buttons["show-answer"])
        XCTAssertTrue(app.buttons["continue-session"].exists)
    }
    func testBoroughSessionCompletesAndReturnsToMap() {
        open("nyc-boroughs", mode: "name")
        for id in ["5", "3", "4", "1", "2"] {
            tap(app.buttons["choice-NYC-BORO-\(id)"])
            tap(app.buttons["continue-session"])
        }
        XCTAssertEqual(app.staticTexts["firstAttemptScore"].label, "5 of 5")
        tap(app.buttons["Back to map"])
        XCTAssertTrue(app.buttons["start-name"].exists)
    }
    func testLandscapeKeepsQuestionAndControlsReachable() {
        open("germany-states", mode: "find")
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        XCTAssertEqual(app.staticTexts["questionPrompt"].label, "Find Sachsen")
        tap(app.buttons["show-answer"])
        tap(app.buttons["continue-session"])
        XCTAssertEqual(app.staticTexts["questionPrompt"].label, "Find Bayern")
    }
    func testLargestTextKeepsAnswersReachable() {
        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        open("germany-states", mode: "name")
        tap(app.buttons["choice-DE-SN"])
        let next = app.buttons["continue-session"]
        XCTAssertTrue(next.isHittable)
        XCTAssertTrue(app.frame.contains(next.frame))
        next.tap()
        XCTAssertTrue(app.staticTexts["questionPrompt"].isHittable)
        XCTAssertTrue(app.frame.contains(app.staticTexts["questionPrompt"].frame))
    }
    func testAccessibleControls() throws {
        XCTAssertTrue(app.buttons["map-us-states"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription, .contrast])
        tap(app.buttons["map-us-states"])
        XCTAssertTrue(app.navigationBars["Practice"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription, .contrast])
        tap(app.buttons["start-find"])
        XCTAssertTrue(app.staticTexts["questionPrompt"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription, .contrast])
        tap(app.buttons["Use area list"])
        tap(app.buttons["area-US-AL"])
        XCTAssertTrue(app.staticTexts["answerFeedback"].firstMatch.label.contains("You chose Alabama"))
    }
    func testGermanyStudySelection() {
        app.buttons["map-germany-states"].tap()
        tap(app.buttons["study-map"])
        let bavaria = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Bayern")).firstMatch
        tap(bavaria)
        let selected = app.staticTexts["study-selection"]
        let updated = NSPredicate(format: "label == %@", "Bayern")
        expectation(for: updated, evaluatedWith: selected)
        waitForExpectations(timeout: 5)
        XCTAssertEqual(selected.label, "Bayern")
    }
    func testCapitalsFlagsAndNicknames() {
        for mode in ["capital", "flag", "nickname"] {
            if mode != "capital" { app.terminate(); app.launch() }
            open("us-states", mode: mode)
            if mode == "capital" { XCTAssertTrue(app.buttons["choice-US-WA"].label.contains("Olympia")) }
            if mode == "flag" { XCTAssertTrue(app.images["quiz-flag"].exists) }
            if mode == "nickname" { XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Evergreen")).firstMatch.exists) }
            tap(app.buttons["choice-US-WA"])
            XCTAssertTrue(app.staticTexts["answerFeedback"].firstMatch.label.contains("That's right."))
        }
    }
    func testCityPopulationModeUsesDatedFigures() {
        open("us-states", mode: "population")
        XCTAssertEqual(app.staticTexts["questionPrompt"].label, "How many people live in New York?")
        XCTAssertTrue(app.buttons["choice-city-US-NY-new-york"].label.contains("8,584,629"))
        tap(app.buttons["choice-city-US-NY-new-york"])
        XCTAssertTrue(app.staticTexts["answerFeedback"].firstMatch.label.contains("2025-07-01"))
    }
    func testLandmarkLocationPinAndDistance() {
        open("us-states", mode: "landmarkLocation")
        XCTAssertEqual(app.staticTexts["questionPrompt"].label, "Locate Statue of Liberty")
        XCTAssertFalse(app.buttons["check-location"].isEnabled)
        let map = app.images["geographicMap"]
        map.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.40)).tap()
        XCTAssertTrue(app.buttons["check-location"].isEnabled)
        XCTAssertTrue(app.frame.contains(app.buttons["check-location"].frame))
        app.buttons["check-location"].tap()
        XCTAssertTrue(app.staticTexts["answerFeedback"].firstMatch.label.contains("km from Statue of Liberty"))
        tap(app.buttons["continue-session"])
        XCTAssertFalse(app.buttons["check-location"].isEnabled)
    }
    func testCoordinateEntryAndCapitalLocation() {
        open("us-states", mode: "capitalLocation")
        XCTAssertEqual(app.staticTexts["questionPrompt"].label, "Locate Olympia")
        tap(app.buttons["Enter coordinates"])
        app.textFields["latitude-input"].tap()
        app.textFields["latitude-input"].typeText("47.04")
        app.textFields["longitude-input"].tap()
        app.textFields["longitude-input"].typeText("-122.90")
        tap(app.buttons["place-coordinate-pin"])
        tap(app.buttons["check-location"])
        XCTAssertTrue(app.staticTexts["answerFeedback"].firstMatch.label.contains("That's right."))
    }
    func testGermanCityLocationsAndReferenceData() {
        open("germany-states", mode: "cityLocation")
        XCTAssertEqual(app.staticTexts["questionPrompt"].label, "Locate Berlin")
        tap(app.buttons["show-answer"])
        XCTAssertTrue(app.staticTexts["answerFeedback"].firstMatch.label.contains("Berlin"))
        app.terminate(); app.launch()
        tap(app.buttons["map-germany-states"])
        tap(app.buttons["browse-facts"])
        tap(app.buttons["Cities"])
        XCTAssertTrue(app.staticTexts["3,685,265 residents"].exists || app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "3,685,265")).firstMatch.exists)
    }
    func testReferenceSearchShowsEmptyStateAndRecovers() {
        tap(app.buttons["map-us-states"])
        XCTAssertTrue(app.buttons["browse-facts"].isHittable)
        app.buttons["browse-facts"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("zzzzzz")
        XCTAssertTrue(app.staticTexts["reference-no-results"].firstMatch.waitForExistence(timeout: 5))
        search.buttons["Clear text"].tap()
        search.tap()
        search.typeText("Washington")
        XCTAssertFalse(app.staticTexts["reference-no-results"].firstMatch.exists)
        tap(app.staticTexts["Washington"])
        XCTAssertTrue(app.staticTexts["Olympia"].waitForExistence(timeout: 5))
    }
    func testNYCNeighborhoodSelection() {
        open("nyc-neighborhoods-focused", mode: "find")
        tap(app.buttons["Use area list"])
        let search = app.searchFields.firstMatch
        search.tap(); search.typeText("Chinatown")
        tap(app.buttons["area-http://nyc.pediacities.com/Resource/Neighborhood/Chinatown"])
        XCTAssertTrue(app.staticTexts["answerFeedback"].firstMatch.exists)
    }
    func testNYCPracticeGroupsAndNameMode() {
        tap(app.buttons["map-nyc-neighborhoods-focused"])
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", "47 areas: 37 in Manhattan")).firstMatch.exists)
        tap(app.buttons["start-find"])
        for (query, id) in [("Bed-Stuy", "http://nyc.pediacities.com/Resource/Neighborhood/Bedford_Stuyvesant"),
                            ("Long Island City", "http://nyc.pediacities.com/Resource/Neighborhood/Long_Island_City"),
                            ("Staten Island", "NYC-BORO-5")] {
            tap(app.buttons["Use area list"])
            let search = app.searchFields.firstMatch
            search.tap(); search.typeText(query)
            tap(app.buttons["area-\(id)"])
            XCTAssertTrue(app.staticTexts["answerFeedback"].firstMatch.label.contains(query))
            tap(app.buttons["continue-session"])
        }
        app.terminate(); app.launch()
        open("nyc-neighborhoods-focused", mode: "name")
        tap(app.buttons["choice-http://nyc.pediacities.com/Resource/Neighborhood/Battery_Park_City"])
        XCTAssertTrue(app.staticTexts["answerFeedback"].firstMatch.label.contains("That's right."))
    }
    func testTimerExpiresAndLocksTheAnswer() {
        app.terminate()
        app.launchArguments += ["--timer-test"]
        app.launch()
        open("us-states", mode: "capital")
        let feedback = app.staticTexts["answerFeedback"].firstMatch
        XCTAssertTrue(feedback.waitForExistence(timeout: 8))
        XCTAssertTrue(feedback.label.contains("Time’s up."))
        XCTAssertFalse(app.buttons["choice-US-WA"].exists)
        tap(app.buttons["continue-session"])
        XCTAssertTrue(app.staticTexts["question-timer"].exists)
    }

}
