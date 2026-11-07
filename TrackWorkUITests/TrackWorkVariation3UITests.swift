import XCTest

final class TrackWorkVariation3UITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["TRACKWORK_UI_TESTING"] = "1"
        app.launchEnvironment["TRACKWORK_UI_TEST_FIXTURE"] = "planShortfall"
    }

    func testReportPeriodDoesNotChangeTodaysTarget() {
        app.launch()
        XCTAssertTrue(app.navigationBars["TrackWork"].waitForExistence(timeout: 5))
        XCTAssertEqual(element("today.remaining").label, "1 office day to go")
        app.workTrackTab(named: "Insights").tap()
        XCTAssertTrue(app.navigationBars["Insights"].waitForExistence(timeout: 5))
        choosePeriod(prefix: "insights", option: "Previous month")
        let reportRange = element("analytics.periodRange").label
        XCTAssertTrue(reportRange.contains("Jun"))
        app.workTrackTab(named: "Home").tap()
        XCTAssertEqual(element("today.progressDetail").label, "7 of 8 office days recorded")
        XCTAssertEqual(element("today.remaining").label, "1 office day to go")
        app.workTrackTab(named: "Insights").tap()
        XCTAssertEqual(element("analytics.periodRange").label, reportRange)
        choosePeriod(prefix: "insights", option: "Current month")
        XCTAssertTrue(app.revealElement("insights.heatmap").exists)
        app.revealElement("insights.section")
        app.segmentedControls["insights.section"].buttons["Trends"].tap()
        XCTAssertTrue(element("dashboard.trendGranularity").exists)
        app.segmentedControls["dashboard.trendGranularity"].buttons["Quarterly"].tap()
        capture("Insights Quarterly")
        app.segmentedControls["dashboard.trendGranularity"].buttons["Yearly"].tap()
        capture("Insights Yearly")
        app.segmentedControls["insights.section"].buttons["Breakdown"].tap()
        XCTAssertTrue(app.revealElement("analytics.workMix").exists)
        app.openRecords()
        XCTAssertTrue(app.navigationBars["Records"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Calendar"].tap()
        XCTAssertTrue(app.navigationBars["Calendar"].waitForExistence(timeout: 5))
    }

    func testVisualReferenceScreens() {
        app.launchEnvironment["TRACKWORK_UI_TEST_FIXTURE"] = "variation3"
        do {
            let appearance = "System appearance"
            app.launch()
            XCTAssertTrue(app.navigationBars["TrackWork"].waitForExistence(timeout: 5))
            capture("\(appearance) Home")
            app.workTrackTab(named: "Calendar").tap()
            XCTAssertTrue(app.navigationBars["Calendar"].waitForExistence(timeout: 5))
            XCTAssertTrue((element("calendar.monthSummary").value as? String)?.contains("12 office days") == true)
            capture("\(appearance) Log")
            app.workTrackTab(named: "Insights").tap()
            XCTAssertTrue(app.navigationBars["Insights"].waitForExistence(timeout: 5))
            capture("\(appearance) Insights Overview")
            app.revealElement("analytics.workMix")
            capture("\(appearance) Insights Mix")
            app.workTrackTab(named: "Settings").tap()
            XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
            capture("\(appearance) Settings")
            app.terminate()
        }
    }

    func testMaximumTextRetainsMetricsAndCalendarAgenda() {
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.revealElement("today.remaining").exists)
        capture("Maximum Text Home")
        app.workTrackTab(named: "Insights").tap()
        XCTAssertTrue(app.revealElement("insights.metrics").exists)
        capture("Maximum Text Insights")
        app.workTrackTab(named: "Calendar").tap()
        XCTAssertTrue(app.revealElement("calendar.agenda").exists)
        XCTAssertFalse(element("calendar.monthGrid").exists)
        capture("Maximum Text Log")
        app.openRecords()
        XCTAssertTrue(app.navigationBars["Records"].waitForExistence(timeout: 5))
        capture("Maximum Text Records")
    }

    func testEmptyLeaveAndOverrideDataStates() {
        for fixture in ["variation3Empty", "variation3LeaveHeavy", "variation3Overrides"] {
            app.launchEnvironment["TRACKWORK_UI_TEST_FIXTURE"] = fixture
            app.launch()
            XCTAssertTrue(element("today.remaining").waitForExistence(timeout: 5))
            capture("\(fixture) Home")
            app.workTrackTab(named: "Insights").tap()
            choosePeriod(prefix: "insights", option: "Current quarter")
            XCTAssertTrue(app.revealElement("insights.heatmap").exists)
            capture("\(fixture) Heatmap")
            app.terminate()
        }
    }

    private func choosePeriod(prefix: String, option: String) {
        app.revealElement("\(prefix).periodPreset").tap()
        let item = app.buttons[option].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 3))
        item.tap()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Variation 3 \(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
