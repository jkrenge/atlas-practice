import XCTest

@MainActor
final class AtlasUITests: XCTestCase {
    var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
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
        for _ in 0..<5 where !element.isHittable {
            // Scroll in the page margin; dragging on the map pans the map.
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.8))
            start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.3)))
        }
        XCTAssertTrue(element.isHittable)
        element.tap()
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
        map.coordinate(withNormalizedOffset: CGVector(dx: 0.13, dy: 0.18)).tap()
        XCTAssertTrue(app.staticTexts["answerFeedback"].firstMatch.label.contains("That's right."))
        tap(app.buttons["continue-session"])
        map.coordinate(withNormalizedOffset: CGVector(dx: 0.925, dy: 0.20)).tap()
        XCTAssertTrue(app.staticTexts["answerFeedback"].firstMatch.label.contains("You chose Rhode Island"))
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
        tap(app.buttons["continue-session"])
        XCTAssertTrue(app.staticTexts["questionPrompt"].exists)
    }
    func testAccessibleControls() throws {
        open("us-states", mode: "find")
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
}
