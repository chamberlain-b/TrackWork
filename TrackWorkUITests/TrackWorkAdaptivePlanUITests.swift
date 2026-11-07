import XCTest

final class TrackWorkAdaptivePlanUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testAugustPlanShowsBoundedMonthAndCompletesBalancedSuggestion() {
        launch()
        openAugustPlan()

        XCTAssertEqual(element(identifier: "officePlan.planned").value as? String, "6")
        XCTAssertEqual(element(identifier: "officePlan.needed").value as? String, "2")
        XCTAssertEqual(
            element(identifier: "officePlan.progress").value as? String,
            "6 of 8 remaining office days planned"
        )
        XCTAssertEqual(
            element(identifier: "officePlan.day.2026-07-31").value as? String,
            "Outside this plan"
        )
        XCTAssertEqual(
            element(identifier: "officePlan.day.2026-08-11").value as? String,
            "Leave"
        )
        attachScreenshot(named: "Adaptive August Plan")

        XCTAssertEqual(
            revealStatic(identifier: "officePlan.day.2026-08-28").value as? String,
            "Public holiday"
        )
        XCTAssertEqual(
            revealStatic(identifier: "officePlan.day.2026-08-31").value as? String,
            "Planned"
        )
        XCTAssertTrue(revealStatic(identifier: "officePlan.week.2026-08-31").exists)

        reveal(identifier: "officePlan.suggest").tap()

        XCTAssertTrue(waitUntil(timeout: 5) {
            self.element(identifier: "officePlan.planned").value as? String == "8"
        })
        XCTAssertEqual(element(identifier: "officePlan.needed").value as? String, "0")
        XCTAssertEqual(
            element(identifier: "officePlan.day.2026-08-05").value as? String,
            "Planned"
        )
        XCTAssertEqual(
            element(identifier: "officePlan.day.2026-08-12").value as? String,
            "Planned"
        )
    }

    func testReplanRequiresConfirmationBeforeReplacingTheMonth() {
        launch()
        openAugustPlan()

        reveal(identifier: "officePlan.replan").tap()

        let replacePlan = element(identifier: "officePlan.confirmReplan")
        XCTAssertTrue(replacePlan.waitForExistence(timeout: 3))
        XCTAssertEqual(replacePlan.label, "Replace plan")
        XCTAssertEqual(element(identifier: "officePlan.planned").value as? String, "6")
        replacePlan.tap()

        XCTAssertTrue(waitUntil(timeout: 5) {
            self.element(identifier: "officePlan.planned").value as? String == "8"
        })
    }

    func testLargestAccessibilityTextUsesAgendaRows() {
        app.launchArguments += [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        launch()
        openAugustPlan()

        XCTAssertTrue(
            element(identifier: "officePlan.accessibilityAgenda.2026-07-27")
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(reveal(identifier: "officePlan.suggest").isHittable)
    }

    private func launch() {
        app.launchEnvironment["TRACKWORK_UI_TESTING"] = "1"
        app.launchEnvironment["TRACKWORK_UI_TEST_FIXTURE"] = "adaptivePlan"
        app.launch()
    }

    private func openAugustPlan() {
        let officePlan = reveal(identifier: "dashboard.officePlan")
        XCTAssertTrue(officePlan.isHittable)
        officePlan.tap()
        XCTAssertTrue(
            app.navigationBars["Adaptive Month Plan"].waitForExistence(timeout: 5)
        )
        XCTAssertEqual(
            element(identifier: "officePlan.referenceDate").label,
            "Planning options as of Wednesday 29 July 2026"
        )

        element(identifier: "officePlan.referenceDate").tap()
        let nextMonth = app.buttons["Next month"]
        XCTAssertTrue(nextMonth.waitForExistence(timeout: 3))
        nextMonth.tap()

        XCTAssertTrue(waitUntil(timeout: 5) {
            self.element(identifier: "officePlan.monthTitle").label == "August 2026 plan"
        })
    }

    private func element(identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func reveal(identifier: String, maxSwipes: Int = 24) -> XCUIElement {
        let target = element(identifier: identifier)
        for _ in 0...maxSwipes {
            if target.exists && target.isHittable {
                return target
            }
            app.swipeUp()
        }
        for _ in 0...maxSwipes {
            if target.exists && target.isHittable {
                return target
            }
            app.swipeDown()
        }

        XCTFail("Unable to reveal \(identifier)")
        return target
    }

    private func revealStatic(identifier: String, maxSwipes: Int = 24) -> XCUIElement {
        let target = element(identifier: identifier)
        for _ in 0...maxSwipes {
            if target.exists && target.isHittable {
                return target
            }
            app.swipeUp()
        }
        for _ in 0...maxSwipes {
            if target.exists && target.isHittable {
                return target
            }
            app.swipeDown()
        }

        XCTFail("Unable to reveal \(identifier)")
        return target
    }

    private func waitUntil(timeout: TimeInterval, condition: @escaping () -> Bool) -> Bool {
        let predicate = NSPredicate { _, _ in condition() }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func attachScreenshot(named name: String) {
        Thread.sleep(forTimeInterval: 0.6)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
