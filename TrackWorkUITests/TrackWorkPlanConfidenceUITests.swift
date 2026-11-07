import XCTest

final class TrackWorkPlanConfidenceUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testCoveredPlanPresentsConfidenceAndOpensPlanning() {
        launch(fixture: "planCovered")

        let plan = element(identifier: "dashboard.officePlan")
        XCTAssertTrue(plan.label.contains("Plan covers target"), plan.label)
        XCTAssertTrue(plan.label.contains("Next planned:"), plan.label)
        XCTAssertTrue(plan.label.contains("30 Jul"), plan.label)
        attachScreenshot(named: "Today Plan Summary")

        let officePlan = reveal(identifier: "dashboard.officePlan")
        XCTAssertTrue(officePlan.isHittable)
        officePlan.tap()
        XCTAssertTrue(app.navigationBars["Adaptive Month Plan"].waitForExistence(timeout: 5))
    }

    func testCompletePlanOpensPlanningFromShortfallSummary() {
        launch(fixture: "planShortfall")


        let completePlan = reveal(identifier: "dashboard.officePlan")
        XCTAssertTrue(completePlan.label.contains("Plan is 1 day short"), completePlan.label)
        XCTAssertTrue(completePlan.isHittable)
        completePlan.tap()

        XCTAssertTrue(app.navigationBars["Adaptive Month Plan"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(identifier: "officePlan.screen").exists)

        let plannedDay = reveal(identifier: "officePlan.day.2026-07-30")
        XCTAssertTrue(plannedDay.isHittable)
        plannedDay.tap()
        XCTAssertTrue(waitUntil(timeout: 5) {
            plannedDay.value as? String == "Planned"
        })

        app.navigationBars.buttons["TrackWork"].tap()
        let reviewPlan = reveal(identifier: "dashboard.officePlan")
        XCTAssertTrue(reviewPlan.label.contains("Plan covers target"), reviewPlan.label)
        XCTAssertTrue(reviewPlan.isHittable)
        reviewPlan.tap()
        XCTAssertTrue(app.navigationBars["Adaptive Month Plan"].waitForExistence(timeout: 5))
    }

    private func launch(fixture: String) {
        app.launchEnvironment["TRACKWORK_UI_TESTING"] = "1"
        app.launchEnvironment["TRACKWORK_UI_TEST_FIXTURE"] = fixture
        app.launch()
        app.revealElement("dashboard.officePlan")
    }

    private func element(identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func valueText(of element: XCUIElement) -> String {
        element.value as? String ?? ""
    }

    private func waitUntil(
        timeout: TimeInterval,
        condition: @escaping () -> Bool
    ) -> Bool {
        let predicate = NSPredicate { _, _ in condition() }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
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
