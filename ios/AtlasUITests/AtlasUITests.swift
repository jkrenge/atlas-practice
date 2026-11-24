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
        openMap(map)
        tap(app.buttons["start-\(mode)"])
        XCTAssertTrue(app.staticTexts["questionPrompt"].waitForExistence(timeout: 5))
        capture("Quiz-\(map)-\(mode)")
    }
    /// NYC maps sit on the New York City page, one level below the home screen.
    func openMap(_ map: String) {
        if map.hasPrefix("nyc-") { tap(app.buttons["map-nyc"]) }
        tap(app.buttons["map-\(map)"])
    }
    func backHome(from map: String) {
        app.navigationBars.buttons.firstMatch.tap()
        if map.hasPrefix("nyc-") {
            XCTAssertTrue(app.buttons["map-\(map)"].waitForExistence(timeout: 5))
            app.navigationBars.buttons.firstMatch.tap()
        }
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
                openMap(mapID)
                XCTAssertTrue(app.buttons["study-map"].waitForExistence(timeout: 5))
                backHome(from: mapID)
                XCTAssertTrue(app.buttons["map-us-states"].waitForExistence(timeout: 5))
            }
            stopMeasuring()
        }
    }
    func testLibraryMapsRemainReachableAtLargestText() {
        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        for mapID in ["us-states", "germany-states", "nyc-boroughs", "nyc-neighborhoods-focused"] {
            openMap(mapID)
            XCTAssertTrue(app.buttons["study-map"].waitForExistence(timeout: 5))
            backHome(from: mapID)
        }
    }
    func testBlueStudyLibraryAndPracticeActions() {
        let featured = app.buttons["map-us-states"]
        XCTAssertTrue(featured.waitForExistence(timeout: 5))
        let home = XCTAttachment(screenshot: app.screenshot())
        home.name = "Blue Study map library"
        home.lifetime = .keepAlways
        add(home)
        // The map preview must also open the collection.
        featured.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)).tap()
        XCTAssertTrue(app.buttons["study-map"].waitForExistence(timeout: 5))
        let setup = XCTAttachment(screenshot: app.screenshot())
        setup.name = "Blue Study practice setup"
        setup.lifetime = .keepAlways
        add(setup)
        tap(app.buttons["start-find"])
        tap(app.buttons["show-answer"])
        let next = app.buttons["continue-session"]
        XCTAssertTrue(next.isHittable)
        XCTAssertTrue(app.frame.contains(next.frame))
        let feedback = XCTAttachment(screenshot: app.screenshot())
        feedback.name = "Blue Study map controls and answer feedback"
        feedback.lifetime = .keepAlways
        add(feedback)
        next.tap()
        XCTAssertEqual(app.staticTexts["questionPrompt"].label, "Find Idaho")
        XCTAssertFalse(app.buttons["continue-session"].exists)
    }
    private func measureGameplay(_ mapID: String) throws {
        guard #available(iOS 26.0, *) else { throw XCTSkip("Frame hitch metrics require iOS 26") }
        let options = XCTMeasureOptions()
        options.iterationCount = 2
        options.invocationOptions = [.manuallyStart, .manuallyStop]
        measure(metrics: [XCTHitchMetric(application: app), XCTCPUMetric(application: app)], options: options) {
            app.terminate()
            app.launch()
            XCTAssertTrue(app.buttons["map-us-states"].waitForExistence(timeout: 5))
            // Bring the card on screen before measuring, so scrolling is not timed. Since the city
            // page, NYC runs also push it, so their numbers differ from runs before it.
            let card = app.buttons[mapID.hasPrefix("nyc-") ? "map-nyc" : "map-\(mapID)"]
            for _ in 0..<4 where !card.isHittable { app.scrollViews.firstMatch.swipeUp() }
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
        XCTAssertTrue(feedbackLabel.hasPrefix("Correct"), feedbackLabel)
        app.buttons["Zoom in"].tap()
        XCTAssertEqual(map.value as? String, "150 percent zoom")
        tap(app.buttons["continue-session"])
        XCTAssertEqual(map.value as? String, "100 percent zoom")
        map.coordinate(withNormalizedOffset: CGVector(dx: 0.925, dy: 0.20)).tap()
        XCTAssertTrue(app.staticTexts["answerFeedback"].firstMatch.label.contains("You chose Rhode Island"))
    }
    func testFindCorrectAnswerAdvancesAfterThreeSeconds() {
        open("us-states", mode: "find")
        let floatingPrompt = app.staticTexts["questionPrompt"]
        XCTAssertEqual(floatingPrompt.label, "Find Washington")
        XCTAssertTrue(app.frame.contains(floatingPrompt.frame))
        XCTAssertFalse(app.staticTexts["map-questionPrompt"].exists, "Show the question only once")
        tap(app.buttons["Use area list"])
        let search = app.searchFields.firstMatch
        search.tap()
        search.typeText("Washington")
        // Before the tap: tap() returns only once the app is idle, which can take most of a second.
        let answeredAt = Date()
        tap(app.buttons["area-US-WA"])
        XCTAssertTrue(app.buttons["continue-session"].waitForExistence(timeout: 2))
        XCTAssertTrue(feedbackLabel.hasPrefix("Correct"), feedbackLabel)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Correct answer with hidden labels and floating controls"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let nextQuestion = NSPredicate(format: "label == %@", "Find Idaho")
        expectation(for: nextQuestion, evaluatedWith: floatingPrompt)
        waitForExpectations(timeout: 5)
        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(answeredAt), 2.9)
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
        pause(3.5) // Longer than the 3 s automatic advance, which must stay cancelled.
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
        for (option, count) in [("25", 25), ("All", 50), ("10", 10)] {
            XCTAssertTrue(app.buttons["map-us-states"].waitForExistence(timeout: 5))
            tap(app.buttons["settings"])
            tap(app.buttons[option])
            app.terminate(); app.launch() // The choice is set in Settings and persists across launches.
            open("us-states", mode: "find")
            XCTAssertTrue(app.staticTexts["Question 1 of \(count)"].exists)
            app.terminate(); app.launch()
        }
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
        // After an answer, leaving asks first so a stray tap cannot discard the session.
        app.buttons["leave-practice"].tap()
        let confirm = app.sheets["End the trip early?"].buttons["End trip"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 2))
        confirm.tap()
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
        XCTAssertTrue(feedbackLabel.hasPrefix("Correct"), feedbackLabel)
    }
    func testNameModeCorrectWrongAndReveal() {
        open("us-states", mode: "name")
        tap(app.buttons["choice-US-WA"])
        XCTAssertTrue(feedbackLabel.hasPrefix("Correct"), feedbackLabel)
        tap(app.buttons["continue-session"])
        tap(app.buttons["choice-US-WA"])
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "You chose Washington")).firstMatch.exists)
        XCTAssertTrue(feedbackLabel.hasPrefix("Incorrect"), feedbackLabel)
        tap(app.buttons["continue-session"])
        tap(app.buttons["show-answer"])
        XCTAssertTrue(app.buttons["continue-session"].exists)
        XCTAssertTrue(feedbackLabel.hasPrefix("Answer shown"), feedbackLabel)
    }
    func testBoroughSessionCompletesAndReturnsToMap() throws {
        open("nyc-boroughs", mode: "name")
        for round in 0..<2 {
            for id in ["5", "3", "4", "1", "2"] {
                tap(app.buttons["choice-NYC-BORO-\(id)"])
                tap(app.buttons["continue-session"])
            }
            XCTAssertEqual(app.staticTexts["firstAttemptScore"].label, "5 of 5")
            if round == 0 {
                capture("Session results")
                // One button shape: both result actions are the same pill.
                XCTAssertEqual(app.buttons["practice-again"].frame.height, app.buttons["finish-practice"].frame.height, accuracy: 1)
                try audit()
                tap(app.buttons["practice-again"])
                XCTAssertTrue(app.staticTexts["Question 1 of 5"].waitForExistence(timeout: 5))
            }
        }
        tap(app.buttons["finish-practice"])
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
        try audit()
        tap(app.buttons["map-us-states"])
        XCTAssertTrue(app.navigationBars["United States"].waitForExistence(timeout: 5))
        // Audit each scroll position, so every row is checked while fully on screen.
        for _ in 0..<3 {
            try audit()
            app.scrollViews.firstMatch.swipeUp()
        }
        try audit()
        for _ in 0..<4 { app.scrollViews.firstMatch.swipeDown() }
        tap(app.buttons["start-find"])
        XCTAssertTrue(app.staticTexts["questionPrompt"].waitForExistence(timeout: 5))
        try audit()
        tap(app.buttons["Use area list"])
        tap(app.buttons["area-US-AL"])
        XCTAssertTrue(app.staticTexts["answerFeedback"].firstMatch.label.contains("You chose Alabama"))
        try audit()
    }

    private var feedbackLabel: String { app.staticTexts["answerFeedback"].firstMatch.label }

    private func audit(scrollEdge: CGFloat = 24) throws {
        // The atlas backdrop glides for about a second after each screen change; audit the settled screen.
        pause(1.2)
        // While scrolled, text can sit under the translucent navigation bar (and its scroll edge
        // effect) or past the screen edge, where the audit samples blurred or black pixels.
        // Only those partly covered elements are skipped; each is audited at another scroll position.
        let bar = app.navigationBars.firstMatch
        let top = bar.exists ? bar.frame.maxY + scrollEdge : 0
        let unobstructed = CGRect(x: app.frame.minX, y: top, width: app.frame.width, height: app.frame.maxY - top)
        var flagged: [XCUIElement] = []
        try app.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription, .contrast]) { issue in
            guard issue.auditType == .contrast, let element = issue.element else { return false }
            if !unobstructed.contains(element.frame) { return true }
            // The auditor sometimes reads the map behind opaque paper; re-measure below what is actually drawn.
            flagged.append(element)
            return true
        }
        for element in flagged {
            let shot = element.screenshot()
            let measured = Self.renderedContrast(shot.image)
            if measured < 4.5 { // Keep what was measured, so a failure can be checked by eye.
                let attachment = XCTAttachment(screenshot: shot)
                attachment.name = "Low contrast \(element.elementType.rawValue) \(element.label) \(element.frame)"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
            XCTAssertGreaterThanOrEqual(measured, 4.5, "Rendered contrast of \(element.label) is \(measured)")
        }
    }

    /// Contrast between the most common color in the image (the background) and the most
    /// contrasting color that covers at least 1% of it (the text, ignoring antialiased edges).
    /// A short label on its own tape in a wide list header has the map as its most common color and too
    /// few text pixels to count, so the measurement is repeated around the text's own pixels.
    static func renderedContrast(_ image: UIImage) -> Double {
        guard let cgImage = image.cgImage else { return 0 }
        let whole = measure(cgImage)
        guard whole.ratio < 4.5, let text = whole.text, let inner = cgImage.cropping(to: text) else { return whole.ratio }
        return max(whole.ratio, measure(inner).ratio)
    }

    private static func measure(_ cgImage: CGImage) -> (ratio: Double, text: CGRect?) {
        let width = cgImage.width, height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return (0, nil) }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        func key(_ index: Int) -> UInt32 {
            // Quantize slightly so near-identical paper shades count together.
            UInt32(pixels[index] & 0xFC) << 16 | UInt32(pixels[index + 1] & 0xFC) << 8 | UInt32(pixels[index + 2] & 0xFC)
        }
        var counts: [UInt32: Int] = [:]
        for index in stride(from: 0, to: pixels.count, by: 4) { counts[key(index), default: 0] += 1 }
        func luminance(_ key: UInt32) -> Double {
            func channel(_ value: UInt32) -> Double {
                let v = Double(value) / 255
                return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * channel(key >> 16 & 0xFF) + 0.7152 * channel(key >> 8 & 0xFF) + 0.0722 * channel(key & 0xFF)
        }
        func contrast(_ a: UInt32, _ b: UInt32) -> Double {
            let (x, y) = (luminance(a), luminance(b))
            return (max(x, y) + 0.05) / (min(x, y) + 0.05)
        }
        guard let background = counts.max(by: { $0.value < $1.value })?.key else { return (0, nil) }
        let minimum = width * height / 100
        let ratio = counts.filter { $0.value >= minimum }.map { contrast($0.key, background) }.max() ?? 0
        // The text: the most contrasting color covering at least 0.2%. Its bounds, padded, hold the text
        // and whatever it is drawn on.
        guard let ink = counts.filter({ $0.value >= max(1, width * height / 500) })
            .max(by: { contrast($0.key, background) < contrast($1.key, background) })?.key else { return (ratio, nil) }
        var (minX, minY, maxX, maxY) = (width, height, -1, -1)
        for y in 0..<height {
            for x in 0..<width where key((y * width + x) * 4) == ink {
                minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        let pad = 8
        let text = CGRect(x: max(0, minX - pad), y: max(0, minY - pad),
                          width: min(width, maxX + pad + 1) - max(0, minX - pad),
                          height: min(height, maxY + pad + 1) - max(0, minY - pad))
        return (ratio, maxX < 0 || text.size == CGSize(width: width, height: height) ? nil : text)
    }

    /// The contrast re-measure must accept a short taped label over the map, and still fail pale text.
    func testRenderedContrastMeasure() {
        func label(_ text: String, ink: UIColor, tape: UIColor, map: UIColor) -> UIImage {
            UIGraphicsImageRenderer(size: CGSize(width: 370, height: 41)).image { context in
                map.setFill(); context.fill(CGRect(x: 0, y: 0, width: 370, height: 41))
                tape.setFill(); context.fill(CGRect(x: 16, y: 10, width: 52, height: 22))
                (text as NSString).draw(at: CGPoint(x: 22, y: 13), withAttributes: [
                    .font: UIFont.monospacedSystemFont(ofSize: 13, weight: .semibold), .foregroundColor: ink])
            }
        }
        let water = UIColor(red: 0.74, green: 0.87, blue: 0.85, alpha: 1)
        let taped = label("About", ink: UIColor(red: 0.11, green: 0.15, blue: 0.16, alpha: 1), tape: .white, map: water)
        XCTAssertGreaterThanOrEqual(Self.renderedContrast(taped), 4.5)
        let pale = label("About", ink: UIColor(white: 0.72, alpha: 1), tape: .white, map: .white)
        XCTAssertLessThan(Self.renderedContrast(pale), 4.5)
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
        app.scrollViews.firstMatch.swipeDown()
        capture("Study selection and state facts")
    }
    func testCapitalsFlagsAndNicknames() {
        for mode in ["capital", "flag", "nickname"] {
            if mode != "capital" { app.terminate(); app.launch() }
            open("us-states", mode: mode)
            if mode == "capital" { XCTAssertTrue(app.buttons["choice-US-WA"].label.contains("Olympia")) }
            if mode == "flag" { XCTAssertTrue(app.images["quiz-flag"].exists) }
            if mode == "nickname" { XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Evergreen")).firstMatch.exists) }
            tap(app.buttons["choice-US-WA"])
            XCTAssertTrue(feedbackLabel.hasPrefix("Correct"), feedbackLabel)
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
        XCTAssertEqual(app.buttons["check-location"].frame.height, app.buttons["show-answer"].frame.height, accuracy: 1)
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
        capture("Coordinate entry")
        app.textFields["latitude-input"].tap()
        app.textFields["latitude-input"].typeText("47.04")
        app.textFields["longitude-input"].tap()
        app.textFields["longitude-input"].typeText("-122.90")
        tap(app.buttons["place-coordinate-pin"])
        tap(app.buttons["check-location"])
        XCTAssertTrue(feedbackLabel.hasPrefix("Correct"), feedbackLabel)
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
        capture("Reference empty search")
        search.buttons["Clear text"].tap()
        search.tap()
        search.typeText("Washington")
        XCTAssertFalse(app.staticTexts["reference-no-results"].firstMatch.exists)
        tap(app.staticTexts["Washington"])
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Olympia")).firstMatch.waitForExistence(timeout: 5))
    }
    func testNYCNeighborhoodSelection() {
        open("nyc-neighborhoods-focused", mode: "find")
        tap(app.buttons["Use area list"])
        let search = app.searchFields.firstMatch
        search.tap(); search.typeText("Chinatown")
        tap(app.buttons["area-http://nyc.pediacities.com/Resource/Neighborhood/Chinatown"])
        XCTAssertTrue(app.staticTexts["answerFeedback"].firstMatch.exists)
    }
    func testNYCPracticeGroupsAndNameMode() throws {
        let city = app.buttons["map-nyc"]
        XCTAssertTrue(city.waitForExistence(timeout: 5))
        for _ in 0..<4 where !city.isHittable { app.scrollViews.firstMatch.swipeUp() }
        capture("Home with the New York City card")
        tap(city)
        XCTAssertTrue(app.navigationBars["New York City"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["map-nyc-boroughs"].exists)
        capture("New York City page")
        try audit(scrollEdge: 0) // Not scrolled yet, so nothing sits under the bar's scroll edge.
        tap(app.buttons["map-nyc-neighborhoods-focused"])
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", "53 areas: 38 in Manhattan")).firstMatch.exists)
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
        XCTAssertTrue(feedbackLabel.hasPrefix("Correct"), feedbackLabel)
    }
    func testTimerExpiresAndLocksTheAnswer() throws {
        app.terminate()
        app.launchArguments += ["--timer-test"]
        app.launch()
        open("us-states", mode: "capital")
        let feedback = app.staticTexts["answerFeedback"].firstMatch
        XCTAssertTrue(feedback.waitForExistence(timeout: 8))
        XCTAssertTrue(feedback.label.hasPrefix("Timed out"), feedback.label)
        capture("Timeout feedback")
        try audit()
        // Choices stay visible to show the answer, but are locked.
        XCTAssertFalse(app.buttons["choice-US-WA"].isEnabled)
        tap(app.buttons["continue-session"])
        XCTAssertTrue(app.staticTexts["question-timer"].exists)
    }

    /// App Store and website screenshots. Runs only from scripts/screenshots.sh, which sets
    /// ATLAS_SCREENSHOTS and a clean status bar; the --ui-testing order makes every frame repeatable.
    func testStoreScreenshots() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["ATLAS_SCREENSHOTS"] != nil, "Run scripts/screenshots.sh")
        func fresh() { app.terminate(); app.launch(); XCTAssertTrue(app.buttons["map-us-states"].waitForExistence(timeout: 5)) }
        func settle() { pause(1.5) } // The backdrop glides and tapes wipe in.

        fresh(); settle(); capture("01-home")
        open("us-states", mode: "find"); settle(); capture("02-find-the-area")
        fresh(); open("us-states", mode: "name")
        tap(app.buttons["choice-US-WA"]); settle(); capture("03-correct")
        fresh(); open("us-states", mode: "flag"); settle(); capture("04-flags")
        fresh(); tap(app.buttons["map-nyc"]); settle(); capture("05-new-york-city")
        fresh(); open("nyc-boroughs", mode: "name")
        for id in ["5", "3", "4", "1", "2"] {
            tap(app.buttons["choice-NYC-BORO-\(id)"])
            tap(app.buttons["continue-session"])
        }
        pause(2.5) // The score ring fills, then the rank stamp lands.
        capture("06-results")
        fresh(); tap(app.buttons["map-us-states"]); tap(app.buttons["browse-facts"]); settle(); capture("07-facts")
        fresh(); tap(app.buttons["settings"]); settle(); capture("08-settings")
    }

    /// Waits for real: XCTWaiter with no expectations returns at once.
    private func pause(_ seconds: TimeInterval) {
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "pause")], timeout: seconds)
    }

    private func capture(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testReferenceDetailsAndCredits() throws {
        tap(app.buttons["map-us-states"])
        tap(app.buttons["browse-facts"])
        capture("Reference states")
        tap(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "state-fact-")).firstMatch)
        capture("State detail")
        tap(app.buttons["Sources & flag credits"])
        capture("State sources expanded")
        app.navigationBars.buttons.firstMatch.tap()
        for category in ["Cities", "Sights"] {
            tap(app.buttons[category])
            capture("Reference \(category)")
            tap(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "place-fact-")).firstMatch)
            XCTAssertTrue(app.images["geographicMap"].waitForExistence(timeout: 5))
            capture("Detail \(category)")
            app.scrollViews.firstMatch.swipeUp()
            capture("Detail sources \(category)")
            app.navigationBars.buttons.firstMatch.tap()
        }
        app.terminate(); app.launch()
        // Settings and credits live on their own screen, at the bottom of home.
        XCTAssertTrue(app.buttons["map-us-states"].waitForExistence(timeout: 5))
        tap(app.buttons["settings"])
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.segmentedControls["session-length"].exists)
        XCTAssertTrue(app.buttons["Help and support"].exists)
        capture("Settings")
        try audit(scrollEdge: 0) // Not scrolled yet, so nothing sits under the bar's scroll edge.
        tap(app.buttons["Map sources and credits"])
        XCTAssertTrue(app.navigationBars["Sources and credits"].waitForExistence(timeout: 5))
        capture("Sources and credits")
    }

    func testAreaSearchEmptyStateAndCancel() {
        open("us-states", mode: "find")
        tap(app.buttons["Use area list"])
        capture("Area selection sheet")
        let search = app.searchFields.firstMatch
        search.tap(); search.typeText("zzzzzz")
        XCTAssertTrue(app.staticTexts["area-no-results"].firstMatch.waitForExistence(timeout: 5))
        capture("Area empty search")
        search.buttons["Clear text"].tap()
        search.typeText("Washington")
        XCTAssertTrue(app.buttons["area-US-WA"].exists)
        app.buttons["close"].tap()
        app.buttons["Cancel"].firstMatch.tap()
        XCTAssertTrue(app.buttons["show-answer"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["answerFeedback"].firstMatch.exists)
    }

    func testLargestTextFactAnswersRemainReachable() {
        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        open("us-states", mode: "capital")
        tap(app.buttons["choice-US-WA"])
        XCTAssertTrue(feedbackLabel.hasPrefix("Correct"), feedbackLabel)
        tap(app.buttons["continue-session"])
        XCTAssertTrue(app.staticTexts["questionPrompt"].isHittable)
    }

}
