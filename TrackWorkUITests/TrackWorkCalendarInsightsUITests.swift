import XCTest

final class TrackWorkCalendarInsightsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["TRACKWORK_UI_TESTING"] = "1"
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    func testCalendarKeepsDetectedAttendanceAndCompactEditorInBothModes() {
        launchCalendar()
        XCTAssertEqual(element("calendar.selectedDay.date").label, "Friday 6 November")
        XCTAssertEqual(element("calendar.selectedDay.status").label, "Home")
        XCTAssertEqual(element("calendar.selectedDay.source").label, "Detected from attendance evidence")
        assertCompactEditor()
        let selectedDay = element("calendar.day.2026-11-06")
        XCTAssertGreaterThanOrEqual(selectedDay.frame.width, 44)
        XCTAssertGreaterThanOrEqual(selectedDay.frame.height, 44)
        capture("Calendar Month")

        element("calendar.selectedDay.edit").tap()
        XCTAssertTrue(element("dayDetail.save").waitForExistence(timeout: 5))
        app.navigationBars.buttons["Calendar"].firstMatch.tap()
        XCTAssertTrue(element("calendar.selectedDay.source").waitForExistence(timeout: 5))
        XCTAssertEqual(element("calendar.selectedDay.status").label, "Home")

        app.segmentedControls["calendar.displayMode"].buttons["Agenda"].tap()
        XCTAssertTrue(element("calendar.agenda").exists)
        assertCompactEditor()
        capture("Calendar Agenda")
        element("calendar.selectedDay.edit").tap()
        XCTAssertTrue(element("dayDetail.save").waitForExistence(timeout: 5))
        app.navigationBars.buttons["Calendar"].firstMatch.tap()
        XCTAssertEqual(element("calendar.selectedDay.source").label, "Detected from attendance evidence")
    }

    func testCalendarSourceDistinguishesCorrectionsLeaveHolidayAndUnknown() {
        launchCalendar()
        for day in ["2026-11-02", "2026-11-03"] {
            app.revealElement("calendar.day.\(day)").tap()
            XCTAssertFalse(element("calendar.selectedDay.source").exists,
                           "Leave and holiday treatments must not claim automatic attendance")
        }
        app.revealElement("calendar.day.2026-11-06").tap()
        app.revealElement("calendar.selectedDay.edit").tap()
        let picker = element("dayDetail.manualStatus")
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.tap()
        app.buttons["Office"].firstMatch.tap()
        element("dayDetail.save").tap()
        XCTAssertTrue(element("calendar.selectedDay.source").waitForExistence(timeout: 5))
        XCTAssertEqual(element("calendar.selectedDay.source").label, "Manually corrected")
        XCTAssertEqual(element("calendar.selectedDay.status").label, "Office")
        capture("Calendar Manual Correction")
        app.workTrackTab(named: "Home").tap()
        XCTAssertEqual(element("today.progressDetail").label, "2 of 10 office days recorded")

        app.terminate()
        launchCalendar(fixture: "phoneUnrecorded")
        XCTAssertFalse(element("calendar.selectedDay.source").exists,
                       "Unknown attendance must not be described as detected")
        XCTAssertNotEqual(element("calendar.selectedDay.status").label, "Home")
        XCTAssertNotEqual(element("calendar.selectedDay.status").label, "Office")
        assertCompactEditor()
        capture("Calendar Unknown Attendance")
    }

    func testInsightsShowsRecordedMixBeforeHistoryAndRetainsTrendNavigation() {
        app.launchEnvironment["TRACKWORK_UI_TEST_FIXTURE"] = "phoneHome"
        app.launch()
        app.workTrackTab(named: "Insights").tap()
        XCTAssertTrue(element("insights.targetCount").waitForExistence(timeout: 5))
        XCTAssertEqual(element("insights.targetCount").value as? String, "1 of 10 office days recorded")
        XCTAssertEqual(element("insights.targetCompletion").label, "10% of target")
        XCTAssertEqual(element("insights.targetStatus").label, "9 office days still needed")
        let mix = element("insights.workMixHeading")
        let history = element("insights.officeAttendance")
        XCTAssertTrue(mix.isHittable, "Recorded attendance should be visible immediately after the target")
        XCTAssertLessThan(mix.frame.minY, history.frame.minY)
        XCTAssertTrue(text(containing: "Office, 33% · 1 of 3 days").exists)
        XCTAssertTrue(text(containing: "Home, 67% · 2 of 3 days").exists)
        XCTAssertTrue(text(containing: "unrecorded days are not included").exists)
        capture("Insights Overview")

        app.revealElement("insights.officeAttendance").tap()
        XCTAssertTrue(app.segmentedControls["dashboard.trendGranularity"].waitForExistence(timeout: 5),
                      "The Overview disclosure must open the dedicated Trends section")
        XCTAssertTrue(app.segmentedControls["dashboard.trendGranularity"].buttons["Monthly"].exists)
        XCTAssertTrue(text(containing: "1 Jun 2026 – 30 Nov 2026").exists)
        XCTAssertTrue(text(containing: "Current periods are still in progress.").exists)
        capture("Insights Trends")
    }

    func testLargestTextKeepsCalendarCorrectionAccessible() {
        app.launchEnvironment["TRACKWORK_UI_TEST_FIXTURE"] = "phoneHome"
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        app.workTrackTab(named: "Calendar").tap()
        XCTAssertTrue(element("calendar.agenda").waitForExistence(timeout: 5))
        XCTAssertFalse(element("calendar.monthGrid").exists)
        let edit = app.revealElement("calendar.selectedDay.edit")
        XCTAssertGreaterThanOrEqual(edit.frame.height, 44)
        XCTAssertGreaterThanOrEqual(edit.frame.minX, 0)
        XCTAssertLessThanOrEqual(edit.frame.maxX, app.frame.maxX)
        XCTAssertEqual(edit.label, "Edit day")
        capture("Calendar Largest Accessibility Text")
        edit.tap()
        XCTAssertTrue(element("dayDetail.save").waitForExistence(timeout: 5))
        app.navigationBars.buttons["Calendar"].firstMatch.tap()
        XCTAssertTrue(element("calendar.selectedDay.source").waitForExistence(timeout: 5))
        XCTAssertEqual(element("calendar.selectedDay.source").label, "Detected from attendance evidence")
    }

    private func launchCalendar(fixture: String = "phoneHome") {
        app.launchEnvironment["TRACKWORK_UI_TEST_FIXTURE"] = fixture
        app.launch()
        app.workTrackTab(named: "Calendar").tap()
        let month = app.segmentedControls["calendar.displayMode"].buttons["Month"]
        XCTAssertTrue(month.waitForExistence(timeout: 5))
        month.tap()
        XCTAssertTrue(element("calendar.selectedDay.date").waitForExistence(timeout: 5))
    }

    private func assertCompactEditor() {
        let edit = app.revealElement("calendar.selectedDay.edit")
        XCTAssertGreaterThanOrEqual(edit.frame.height, 44)
        XCTAssertLessThan(edit.frame.width, app.frame.width * 0.5)
        XCTAssertGreaterThanOrEqual(edit.frame.minX, 0)
        XCTAssertLessThanOrEqual(edit.frame.maxX, app.frame.maxX)
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func text(containing value: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", value)).firstMatch
    }

    private func capture(_ name: String) {
        Thread.sleep(forTimeInterval: 0.6)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Approved Direction \(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
