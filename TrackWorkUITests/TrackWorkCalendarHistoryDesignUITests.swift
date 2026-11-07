import XCTest

final class TrackWorkCalendarHistoryDesignUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["TRACKWORK_UI_TESTING"] = "1"
        app.launchEnvironment["TRACKWORK_UI_TEST_FIXTURE"] = "planCovered"
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testCalendarAndHistoryPresentPrimaryHierarchy() {
        app.launch()

        app.workTrackTab(named: "Calendar").tap()
        XCTAssertTrue(app.navigationBars["Calendar"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(identifier: "calendar.monthOverview").waitForExistence(timeout: 3))
        XCTAssertTrue(element(identifier: "calendar.monthSummary").exists)
        XCTAssertTrue(element(identifier: "calendar.monthGrid").exists)
        attachScreenshot(named: "Calendar Design")

        XCTAssertTrue(element(identifier: "calendar.selectedDay.date").exists)
        let previousDay = element(identifier: "calendar.day.2026-07-28")
        XCTAssertTrue(previousDay.exists)
        previousDay.tap()
        XCTAssertEqual(
            element(identifier: "calendar.selectedDay.date").label,
            "Tuesday 28 July"
        )
        XCTAssertTrue(reveal(identifier: "calendar.selectedDay.edit").isHittable)
        attachScreenshot(named: "Calendar Selected Day")

        app.openRecords()
        XCTAssertTrue(app.navigationBars["Records"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(identifier: "history.overview").waitForExistence(timeout: 3))
        XCTAssertTrue(element(identifier: "history.filters").exists)
        attachScreenshot(named: "Records Design")

        XCTAssertTrue(reveal(identifier: "history.record.2026-07-28").exists)
        attachScreenshot(named: "Records Record Design")
    }

    func testCalendarAndHistoryReflowAtLargestAccessibilityText() {
        app.launchArguments += [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launch()

        app.workTrackTab(named: "Calendar").tap()
        XCTAssertTrue(element(identifier: "calendar.monthOverview").waitForExistence(timeout: 5))
        XCTAssertTrue(reveal(identifier: "calendar.agenda").exists)
        XCTAssertFalse(element(identifier: "calendar.monthGrid").exists)
        XCTAssertTrue(element(identifier: "calendar.selectedDay.date").exists)

        app.openRecords()
        XCTAssertTrue(element(identifier: "history.overview").waitForExistence(timeout: 5))
        XCTAssertTrue(reveal(identifier: "history.filters").exists)
        XCTAssertTrue(reveal(identifier: "history.record.2026-07-28").exists)
        attachScreenshot(named: "Records Accessibility Text")
    }

    private func element(identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func reveal(identifier: String, maxSwipes: Int = 10) -> XCUIElement {
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

    private func attachScreenshot(named name: String) {
        Thread.sleep(forTimeInterval: 0.6)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
