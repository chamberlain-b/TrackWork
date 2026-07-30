import XCTest

final class TrackWorkPlanConfidenceUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["TRACKWORK_UI_TESTING"] = "1"
        app.launchEnvironment["TRACKWORK_UI_TEST_FIXTURE"] = "planCovered"
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testCoveredPlanPresentsConfidenceAndOpensPlanning() {
        XCTAssertTrue(
            element(identifier: "dashboard.planConfidence").waitForExistence(timeout: 8)
        )
        XCTAssertEqual(
            element(identifier: "dashboard.planConfidence.status").label,
            "Plan covers target"
        )

        let completed = element(identifier: "dashboard.planConfidence.completed")
        XCTAssertEqual(valueText(of: completed), "7 of 8 required")

        let remaining = element(identifier: "dashboard.planConfidence.remaining")
        XCTAssertEqual(valueText(of: remaining), "1")

        let completionDate = element(identifier: "dashboard.planConfidence.completionDate")
        XCTAssertEqual(completionDate.label, "Completion date")
        XCTAssertEqual(valueText(of: completionDate), "Thursday 30 July 2026")

        let nextDate = element(identifier: "dashboard.planConfidence.nextDate")
        XCTAssertEqual(nextDate.label, "Next planned office day")
        XCTAssertEqual(valueText(of: nextDate), "Thursday 30 July")

        XCTAssertEqual(
            element(identifier: "dashboard.referenceDate").label,
            "Wednesday 29 July 2026"
        )
        XCTAssertTrue(
            app.staticTexts["Plans are reminders. Only confirmed attendance counts."].exists
        )
        attachScreenshot(named: "Summary Plan Confidence")

        let officePlan = reveal(identifier: "dashboard.officePlan")
        XCTAssertTrue(officePlan.isHittable)
        officePlan.tap()
        XCTAssertTrue(app.navigationBars["Adaptive Month Plan"].waitForExistence(timeout: 5))
    }

    private func element(identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func valueText(of element: XCUIElement) -> String {
        element.value as? String ?? ""
    }

    private func reveal(identifier: String) -> XCUIElement {
        let target = element(identifier: identifier)
        for _ in 0...5 {
            if target.exists && target.isHittable {
                return target
            }
            app.swipeUp()
        }

        XCTFail("Unable to reveal \(identifier)")
        return target
    }

    private func attachScreenshot(named name: String) {
        Thread.sleep(forTimeInterval: 0.6)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
