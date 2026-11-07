import XCTest

/// Uses actual simulator settings, rather than launch arguments that only rename screenshots.
final class TrackWorkAccessibilityAppearanceUITests: XCTestCase {
    func testBoldTextAndReduceMotionKeepCoreScreensReadable() {
        continueAfterFailure = false
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        let originalBold = setAccessibilitySwitch("Bold Text", page: "DISPLAY_AND_TEXT", enabled: true, settings: settings)
        let originalMotion = setAccessibilitySwitch("Reduce Motion", page: "MOTION_TITLE", enabled: true, settings: settings)
        defer {
            _ = setAccessibilitySwitch("Reduce Motion", page: "MOTION_TITLE", enabled: originalMotion, settings: settings)
            _ = setAccessibilitySwitch("Bold Text", page: "DISPLAY_AND_TEXT", enabled: originalBold, settings: settings)
        }

        let app = XCUIApplication()
        app.launchEnvironment["TRACKWORK_UI_TESTING"] = "1"
        app.launchEnvironment["TRACKWORK_UI_TEST_FIXTURE"] = "variation3"
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXXXL"]
        app.launch()
        for tab in ["Home", "Calendar", "Insights", "Settings"] {
            app.workTrackTab(named: tab).tap()
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "Variation 3 Bold Text Reduce Motion Extra Large \(tab)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        XCTAssertTrue(app.navigationBars["Settings"].exists)
    }

    @discardableResult
    private func setAccessibilitySwitch(_ label: String, page: String, enabled: Bool, settings: XCUIApplication) -> Bool {
        settings.activate()
        for _ in 0..<6 {
            let back = settings.navigationBars.buttons["BackButton"].firstMatch
            guard back.exists else { break }
            back.tap()
        }
        let accessibility = settings.buttons["com.apple.settings.accessibility"].firstMatch
        XCTAssertTrue(accessibility.waitForExistence(timeout: 5))
        accessibility.tap()
        let destination = settings.buttons[page].firstMatch
        XCTAssertTrue(destination.waitForExistence(timeout: 5))
        destination.tap()
        let toggle = settings.switches.matching(NSPredicate(format: "label BEGINSWITH[c] %@", label)).firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), settings.debugDescription)
        let original = toggle.value as? String == "1"
        if original != enabled { toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap() }
        let state = NSPredicate(format: "value == %@", enabled ? "1" : "0")
        let expectation = XCTNSPredicateExpectation(predicate: state, object: toggle)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
        return original
    }
}
