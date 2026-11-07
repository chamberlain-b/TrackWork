import XCTest

final class TrackWorkInsightsRefinementUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["TRACKWORK_UI_TESTING"] = "1"
        app.launchEnvironment["TRACKWORK_UI_TEST_FIXTURE"] = "variation3"
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    func testUnconfiguredInsightsDoesNotPresentFallbackAsSavedTarget() {
        launch(fixture: "firstLaunch")
        openInsights()
        XCTAssertEqual(element("insights.targetStatus").label, "Choose an office target in Settings")
        XCTAssertFalse(element("insights.targetCompletion").exists)
        capture("Unconfigured target")
    }

    func testTargetCompletionIsSeparateFromOfficeShareAndHomePeriod() {
        launch(fixture: "approvedHome")
        XCTAssertEqual(element("today.progressDetail").label, "1 of 8 office days recorded")
        openInsights()

        XCTAssertEqual(element("insights.targetCount").value as? String, "1 of 8 office days recorded")
        let completion = element("insights.targetCompletion").label
        XCTAssertTrue(completion.contains("of target"), completion)
        XCTAssertFalse(completion.contains("50%"), "Recorded office share must not become target completion")
        XCTAssertEqual(element("insights.targetStatus").label, "7 office days still needed")
        app.revealElement("analytics.workMix")
        XCTAssertTrue(text(containing: "50% · 1 of 2 days").exists)
        capture("Target versus recorded share")

        choosePeriod("Previous month")
        let range = element("analytics.periodRange").label
        XCTAssertTrue(range.contains("Sep"), range)
        XCTAssertTrue(element("insights.targetStatus").label.contains("Period ended"))
        XCTAssertFalse(element("insights.targetStatus").label.localizedCaseInsensitiveContains("on track"))

        app.workTrackTab(named: "Home").tap()
        XCTAssertEqual(element("today.progressDetail").label, "1 of 8 office days recorded")
        XCTAssertEqual(element("today.remaining").label, "7 office days to go")
        openInsights()
        XCTAssertEqual(element("analytics.periodRange").label, range)
    }

    func testNativePeriodTrendsAndCalculationNavigation() {
        launch()
        openInsights()
        let exclusions = app.buttons["Leave & exclusions"].firstMatch
        reveal(exclusions)
        exclusions.tap()
        XCTAssertTrue(element("insights.targetCount").isHittable,
                      "Opening Breakdown from the lower Overview section should return to its summary")
        chooseSection("Overview")
        choosePeriod("Custom")
        XCTAssertTrue(app.revealElement("insights.customStartDate").isHittable)
        XCTAssertTrue(app.revealElement("insights.customEndDate").isHittable)
        capture("Custom period controls")

        choosePeriod("Current quarter")
        let range = element("analytics.periodRange").label
        XCTAssertTrue(range.contains("Jul") && range.contains("Sep"), range)
        chooseSection("Trends")
        for granularity in ["Monthly", "Quarterly", "Yearly"] {
            choose(identifier: "dashboard.trendGranularity", option: granularity)
            XCTAssertTrue(app.revealElement("analytics.attendanceTrend").exists)
            capture("Trends \(granularity)")
        }

        chooseSection("Breakdown")
        XCTAssertTrue(app.revealElement("insights.targetCount").exists)
        XCTAssertTrue(app.revealElement("insights.eligibility").exists)
        app.revealElement("compliance.calculation.disclosure").tap()
        XCTAssertTrue(text(containing: "Required office days").exists)
        capture("Breakdown calculation")
        app.revealElement("analytics.workMix")
        let details = app.buttons["Compliance details"].firstMatch
        reveal(details)
        details.tap()
        XCTAssertTrue(app.navigationBars["Compliance details"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Insights"].tap()
        XCTAssertTrue(app.navigationBars["Insights"].waitForExistence(timeout: 5))
    }

    /// Run this under both actual simulator appearances; the test does not change system settings.
    func testInsightsVisualEvidenceInCurrentAppearance() {
        launch()
        openInsights()
        XCTAssertTrue(element("insights.targetCount").isHittable)
        XCTAssertTrue(element("insights.targetStatus").isHittable)
        capture("Overview target")
        let scroll = app.scrollViews.firstMatch
        scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.70))
            .press(forDuration: 0.1, thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.40)))
        capture("Overview attendance trend")
        app.revealElement("analytics.workMix")
        capture("Overview recorded mix")
        app.revealElement("insights.eligibility")
        capture("Overview leave and exclusions")
        app.revealElement("insights.heatmap")
        capture("Overview attendance pattern")
    }

    func testLargestTextRetainsSummaryAndNativeMenus() {
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        launch()
        openInsights()
        XCTAssertTrue(app.revealElement("insights.targetCount").isHittable)
        capture("Largest text target")
        XCTAssertTrue(app.revealElement("insights.targetCompletion").isHittable)
        XCTAssertTrue(app.revealElement("insights.targetStatus").isHittable)
        capture("Largest text completion and status")
        chooseSection("Trends")
        choose(identifier: "dashboard.trendGranularity", option: "Quarterly")
        XCTAssertTrue(app.revealElement("analytics.attendanceTrend").exists)
        capture("Largest text trend")
        chooseSection("Breakdown")
        XCTAssertTrue(app.revealElement("insights.eligibility").exists)
        capture("Largest text eligibility")
        app.revealElement("compliance.calculation.disclosure").tap()
        XCTAssertTrue(text(containing: "Required office days").exists)
        chooseSection("Overview")
        choosePeriod("Custom")
        XCTAssertTrue(app.revealElement("insights.customStartDate").isHittable)
        XCTAssertTrue(app.revealElement("insights.customEndDate").isHittable)
        capture("Largest text custom period")
    }

    func testEmptyAndLeaveHeavyPeriodsExplainTheirDenominators() {
        launch(fixture: "variation3Empty")
        openInsights()
        XCTAssertEqual(element("insights.targetCount").value as? String, "0 of 10 office days recorded")
        XCTAssertEqual(element("insights.targetCompletion").label, "0% of target")
        XCTAssertEqual(element("insights.targetStatus").label, "10 office days still needed")
        capture("Empty target")
        app.revealElement("analytics.attendanceTrend")
        XCTAssertTrue(text(containing: "Record attendance to start your trend.").exists)
        app.revealElement("analytics.workMix")
        XCTAssertTrue(text(containing: "No eligible recorded days in this period.").exists)
        capture("Empty recorded history")
        app.terminate()

        launch(fixture: "variation3LeaveHeavy")
        openInsights()
        chooseSection("Breakdown")
        let targetCount = element("insights.targetCount").value as? String ?? ""
        XCTAssertFalse(targetCount.contains(" of 10 "), "Eligible leave should reduce the prorated monthly target")
        app.revealElement("insights.eligibility")
        let leave = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Full-day leave")).firstMatch
        XCTAssertTrue(leave.exists)
        XCTAssertTrue((leave.value as? String ?? "").hasPrefix("−"), "Show the effective eligible-day reduction")
        XCTAssertTrue(text(containing: "Overlapping days count once.").exists)
        capture("Leave adjusted eligibility")
        app.revealElement("compliance.calculation.disclosure").tap()
        XCTAssertTrue(text(containing: "Leave and exclusions").exists)
        capture("Leave adjusted calculation")
    }

    /// Read-only navigation with the unconfigured, in-memory first-launch fixture.
    func testSettingsAndFirstLaunchReadOnlyEvidence() {
        launch(fixture: "firstLaunch")
        XCTAssertEqual(app.alerts.count, 0)
        XCTAssertTrue(text(containing: "Set your office target").exists)
        capture("First launch Home")
        app.workTrackTab(named: "Settings").tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        capture("Settings policy before optional tracking")
        app.revealElement("settings.privacyData")
        capture("Settings notifications and privacy")
        app.revealElement("settings.privacyData").tap()
        capture("Settings privacy and data")
        app.navigationBars.buttons["Settings"].tap()
        app.revealElement("settings.editPolicy").tap()
        app.revealElement("settings.workdays").tap()
        XCTAssertTrue(app.navigationBars["Workdays"].waitForExistence(timeout: 5))
        capture("Settings workdays")
        app.navigationBars.buttons["Set Up Work Policy"].tap()
        element("settings.cancelPolicy").tap()
        app.revealElement("settings.automaticAttendance").tap()
        XCTAssertTrue(app.navigationBars["Automatic Attendance"].waitForExistence(timeout: 5))
        capture("Setup automatic attendance")
        app.navigationBars.buttons["Settings"].tap()
        app.revealElement("settings.locations").tap()
        XCTAssertTrue(app.navigationBars["Locations"].waitForExistence(timeout: 5))
        capture("Setup locations")
        XCTAssertEqual(app.alerts.count, 0)
    }

    private func launch(fixture: String = "variation3") {
        app.launchEnvironment["TRACKWORK_UI_TEST_FIXTURE"] = fixture
        app.launch()
        XCTAssertTrue(app.navigationBars["TrackWork"].waitForExistence(timeout: 8))
    }

    private func openInsights() {
        app.workTrackTab(named: "Insights").tap()
        XCTAssertTrue(app.navigationBars["Insights"].waitForExistence(timeout: 5))
    }

    private func choosePeriod(_ option: String) {
        choose(identifier: "insights.periodPreset", option: option)
    }

    private func chooseSection(_ option: String) {
        choose(identifier: "insights.section", option: option)
    }

    private func choose(identifier: String, option: String) {
        let control = revealTopControl(identifier)
        let segmented = app.segmentedControls[identifier]
        if segmented.exists {
            segmented.buttons[option].tap()
        } else {
            control.tap()
            let item = app.buttons[option].firstMatch
            for _ in 0..<6 {
                if item.exists && item.isHittable { break }
                let menu = app.collectionViews.firstMatch
                guard menu.exists else { break }
                let visible = menu.frame.intersection(app.frame.insetBy(dx: 0, dy: 80))
                let origin = app.coordinate(withNormalizedOffset: .zero)
                origin.withOffset(CGVector(dx: visible.midX, dy: visible.maxY - 60))
                    .press(forDuration: 0.1, thenDragTo: origin.withOffset(CGVector(dx: visible.midX, dy: visible.minY + 60)))
            }
            XCTAssertTrue(item.exists && item.isHittable, "Missing \(option) in \(identifier)")
            item.tap()
        }
    }

    private func revealTopControl(_ identifier: String) -> XCUIElement {
        let target = element(identifier)
        for _ in 0..<16 {
            if target.exists && target.isHittable { return target }
            if target.exists && target.frame.minY < app.frame.midY {
                app.swipeDown()
            } else {
                app.swipeUp()
            }
        }
        XCTAssertTrue(target.isHittable, "Unable to reveal \(identifier)")
        return target
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func text(containing value: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", value)).firstMatch
    }

    private func reveal(_ target: XCUIElement) {
        for _ in 0..<12 {
            if target.exists && target.isHittable { return }
            app.swipeUp()
        }
        XCTFail("Unable to reveal \(target)")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Insights Refinement \(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
