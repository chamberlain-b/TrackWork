import XCTest

final class TrackWorkTodayDesignUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["TRACKWORK_UI_TESTING"] = "1"
        app.launchEnvironment["TRACKWORK_UI_TEST_FIXTURE"] = "planShortfall"
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testCorrectionUpdatesStatusWeekAndTargetTogether() {
        app.launch()

        let status = element(identifier: "today.status")
        XCTAssertTrue(status.waitForExistence(timeout: 8))
        XCTAssertEqual(status.label, "Not recorded")
        XCTAssertTrue(element(identifier: "today.correct").isHittable,
                      "Recording today should be visible on launch")
        XCTAssertTrue(element(identifier: "today.remaining").isHittable,
                      "The monthly target should be visible on launch")
        XCTAssertEqual(element(identifier: "today.remaining").label, "1 office day to go")
        XCTAssertEqual(element(identifier: "today.progressDetail").label, "7 of 8 office days recorded")

        app.revealElement("today.correct").tap()
        XCTAssertTrue(element(identifier: "dayDetail.save").waitForExistence(timeout: 5))
        choosePicker(identifier: "dayDetail.manualStatus", option: "Office")
        element(identifier: "dayDetail.save").tap()

        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertEqual(status.label, "Office")
        XCTAssertEqual(element(identifier: "today.remaining").label, "Monthly target met")
        XCTAssertEqual(element(identifier: "today.progressDetail").label, "8 of 8 office days recorded")

        let todayInWeek = app.revealElement("today.week.2026-07-29")
        XCTAssertTrue(todayInWeek.label.localizedCaseInsensitiveContains("Office"), todayInWeek.label)
        attachScreenshot(named: "Today Corrected")
    }

    func testApprovedHomeSeparatesRecordedShareFromTargetProgress() {
        app.launchEnvironment["TRACKWORK_UI_TEST_FIXTURE"] = "approvedHome"
        app.launch()

        let share = element(identifier: "today.monthlyShare")
        XCTAssertTrue(share.waitForExistence(timeout: 8))
        XCTAssertTrue(share.label.contains("50%"), share.label)
        XCTAssertTrue(share.label.contains("of recorded workdays · 1 of 2"), share.label)
        XCTAssertEqual(element(identifier: "today.remaining").label, "7 office days to go")
        XCTAssertEqual(element(identifier: "today.progressDetail").label, "1 of 8 office days recorded")
        XCTAssertEqual(element(identifier: "today.status").label, "Not a workday")
        XCTAssertTrue(element(identifier: "today.checkLocation").isHittable)
        let correction = element(identifier: "today.correct")
        XCTAssertTrue(correction.isHittable)
        if app.tabBars.firstMatch.exists {
            XCTAssertLessThanOrEqual(correction.frame.maxY, app.tabBars.firstMatch.frame.minY,
                                     "The secondary correction must remain above the native tab bar on launch")
        }
        attachScreenshot(named: "Approved Home")

        app.revealElement("today.week.2026-10-02").tap()
        XCTAssertTrue(element(identifier: "dayDetail.save").waitForExistence(timeout: 5))
        choosePicker(identifier: "dayDetail.manualStatus", option: "Home")
        element(identifier: "dayDetail.save").tap()

        XCTAssertTrue(share.waitForExistence(timeout: 5))
        XCTAssertTrue(share.label.contains("0%"), share.label)
        XCTAssertTrue(share.label.contains("of recorded workdays · 0 of 2"), share.label)
        XCTAssertEqual(element(identifier: "today.remaining").label, "8 office days to go")
        XCTAssertEqual(element(identifier: "today.progressDetail").label, "0 of 8 office days recorded")
    }

    func testEmptyHomeExplainsMissingRecordedShare() {
        app.launchEnvironment["TRACKWORK_UI_TEST_FIXTURE"] = "variation3Empty"
        app.launch()

        let share = element(identifier: "today.monthlyShare")
        XCTAssertTrue(share.waitForExistence(timeout: 8))
        XCTAssertTrue(share.label.contains("No recorded workdays yet"), share.label)
        XCTAssertTrue(share.label.contains("—"), share.label)
        XCTAssertFalse(share.label.contains("0%"), share.label)
        XCTAssertEqual(element(identifier: "today.progressDetail").label, "0 of 10 office days recorded")
        attachScreenshot(named: "Home No Recorded Workdays")
    }

    func testDetectedAndUnknownAttendanceKeepCorrectionSecondaryInsideTodayCard() {
        for (fixture, expectedStatus, expectedSource) in [
            ("phoneHome", "Home", "Detected from attendance evidence"),
            ("phoneOffice", "Office", "Detected from attendance evidence"),
            ("phoneUnrecorded", "Not recorded", "No attendance recorded yet")
        ] {
            app.launchEnvironment["TRACKWORK_UI_TEST_FIXTURE"] = fixture
            app.launch()

            let status = element(identifier: "today.status")
            XCTAssertTrue(status.waitForExistence(timeout: 8))
            XCTAssertEqual(status.label, expectedStatus)
            XCTAssertEqual(status.value as? String, expectedSource)

            let correction = element(identifier: "today.correct")
            XCTAssertTrue(correction.isHittable)
            XCTAssertEqual(app.buttons.matching(identifier: "today.correct").count, 1)
            XCTAssertLessThan(correction.frame.width, app.frame.width * 0.75,
                              "The correction must stay a compact secondary action")
            XCTAssertGreaterThanOrEqual(correction.frame.height, 44)
            XCTAssertGreaterThanOrEqual(correction.frame.minY, status.frame.maxY)
            XCTAssertLessThanOrEqual(correction.frame.maxY,
                                     element(identifier: "today.checkLocation").frame.minY,
                                     "Correction belongs inside Today, before Check location and the week")
            attachScreenshot(named: "Compact correction - \(fixture)")

            correction.tap()
            XCTAssertTrue(element(identifier: "dayDetail.save").waitForExistence(timeout: 5))
            app.buttons["Cancel"].firstMatch.tap()
            XCTAssertTrue(status.waitForExistence(timeout: 5))
            XCTAssertEqual(status.label, expectedStatus, "Cancelling must retain the automatic/unknown result")
            app.terminate()
        }
    }

    func testCompactCorrectionPreservesDetectedSourceAndUpdatesFinalStatusOnSave() {
        app.launchEnvironment["TRACKWORK_UI_TEST_FIXTURE"] = "phoneHome"
        app.launch()
        let status = element(identifier: "today.status")
        XCTAssertTrue(status.waitForExistence(timeout: 8))
        XCTAssertEqual(status.label, "Home")
        XCTAssertEqual(status.value as? String, "Detected from attendance evidence")
        XCTAssertEqual(element(identifier: "today.progressDetail").label, "1 of 10 office days recorded")

        element(identifier: "today.correct").tap()
        choosePicker(identifier: "dayDetail.manualStatus", option: "Office")
        element(identifier: "dayDetail.save").tap()

        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertEqual(status.label, "Office")
        XCTAssertEqual(status.value as? String, "Manually corrected")
        XCTAssertEqual(element(identifier: "today.progressDetail").label, "2 of 10 office days recorded")
        XCTAssertTrue(app.revealElement("today.week.2026-11-06").label.contains("Office"))
        attachScreenshot(named: "Compact correction saved")
    }

    func testLargestTextKeepsCompactCorrectionReadableAndOpensEditor() {
        app.launchEnvironment["TRACKWORK_UI_TEST_FIXTURE"] = "phoneHome"
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()

        let correction = app.revealElement("today.correct")
        XCTAssertEqual(correction.label, "Correct today")
        XCTAssertGreaterThanOrEqual(correction.frame.height, 44)
        XCTAssertGreaterThanOrEqual(correction.frame.minX, 0)
        XCTAssertLessThanOrEqual(correction.frame.maxX, app.frame.maxX)
        attachScreenshot(named: "Compact correction largest text")
        correction.tap()
        XCTAssertTrue(element(identifier: "dayDetail.save").waitForExistence(timeout: 5))
        app.buttons["Cancel"].firstMatch.tap()
        XCTAssertTrue(element(identifier: "today.status").exists)
    }

    private func choosePicker(identifier: String, option: String) {
        let picker = element(identifier: identifier)
        XCTAssertTrue(picker.waitForExistence(timeout: 3), "Missing picker \(identifier)")
        picker.tap()

        let optionElement = app.buttons[option].firstMatch
        XCTAssertTrue(optionElement.waitForExistence(timeout: 3), "Missing picker option \(option)")
        optionElement.tap()
    }

    private func element(identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func attachScreenshot(named name: String) {
        Thread.sleep(forTimeInterval: 0.6)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
