import XCTest

/// Complements the existing Home, Insights, Records and policy screenshots with editing states.
/// The caller selects the simulator appearance; fixtures stay in memory and no OS settings change.
final class TrackWorkColourRefinementUITests: XCTestCase {
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

    func testCalendarEditorShowsEnabledAndLockedControlsWithoutSaving() {
        launch(fixture: "variation3")
        app.workTrackTab(named: "Calendar").tap()
        XCTAssertTrue(element("calendar.monthGrid").waitForExistence(timeout: 5))
        capture("Calendar month")

        let selectedDay = element("calendar.day.2026-07-28")
        XCTAssertTrue(selectedDay.exists)
        selectedDay.tap()
        XCTAssertEqual(element("calendar.selectedDay.date").label, "Tuesday 28 July")
        let originalStatus = element("calendar.selectedDay.status").label
        reveal("calendar.selectedDay.edit").tap()
        XCTAssertTrue(element("dayDetail.save").waitForExistence(timeout: 5))
        XCTAssertTrue(element("dayDetail.save").isEnabled)
        XCTAssertTrue(element("dayDetail.manualStatus").isEnabled)
        capture("Day editor enabled controls")

        reveal("dayDetail.leaveType").tap()
        let annualLeave = app.buttons["Annual leave"].firstMatch
        XCTAssertTrue(annualLeave.waitForExistence(timeout: 3))
        annualLeave.tap()
        XCTAssertFalse(element("dayDetail.manualStatus").isEnabled)
        XCTAssertTrue(element("dayDetail.save").isEnabled)
        capture("Day editor leave locks attendance")

        app.navigationBars.buttons["Calendar"].tap()
        XCTAssertTrue(element("calendar.selectedDay.date").waitForExistence(timeout: 5))
        XCTAssertEqual(element("calendar.selectedDay.status").label, originalStatus,
                       "Leaving the editor must discard the temporary leave selection")
        capture("Calendar selected day")
    }

    func testLargestTextCalendarEditorRetainsStatusAndSave() {
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        launch(fixture: "variation3")
        app.workTrackTab(named: "Calendar").tap()
        XCTAssertTrue(element("calendar.monthOverview").waitForExistence(timeout: 5))
        XCTAssertFalse(element("calendar.monthGrid").exists)
        reveal("calendar.selectedDay.edit")
        XCTAssertTrue(element("calendar.selectedDay.date").exists)
        capture("Largest text calendar selected day")
        element("calendar.selectedDay.edit").tap()
        XCTAssertTrue(element("dayDetail.save").waitForExistence(timeout: 5))
        XCTAssertTrue(element("dayDetail.save").isHittable)
        XCTAssertTrue(reveal("dayDetail.manualStatus").isHittable)
        capture("Largest text day editor")
        XCTAssertTrue(reveal("dayDetail.leaveType").isHittable)
        let exclusion = reveal("dayDetail.customExcluded")
        for _ in 0..<3 where exclusion.frame.maxY > app.frame.maxY - 110 {
            let form = app.collectionViews.firstMatch
            form.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
                .press(forDuration: 0.1, thenDragTo: form.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.42)))
        }
        XCTAssertTrue(exclusion.isHittable)
        XCTAssertLessThan(exclusion.frame.maxY, app.frame.maxY - 100,
                          "The exclusion control should be fully above the tab bar for visual review")
        capture("Largest text optional day controls")
    }

    func testDisabledLocationSaveAndDestructiveControlStayDistinct() {
        launch(fixture: "firstLaunch")
        app.workTrackTab(named: "Settings").tap()
        reveal("settings.locations").tap()
        XCTAssertTrue(app.navigationBars["Locations"].waitForExistence(timeout: 5))
        app.buttons["locationSetup.home"].tap()
        XCTAssertTrue(element("placeEditor.save").waitForExistence(timeout: 5))
        XCTAssertFalse(element("placeEditor.save").isEnabled)
        XCTAssertTrue(element("placeEditor.searchAddress").isEnabled)
        capture("Location editor disabled save")

        let name = app.textFields["placeEditor.name"]
        XCTAssertTrue(name.exists)
        name.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        capture("Location name focused")
        app.navigationBars.buttons["Locations"].tap()
        app.navigationBars.buttons["Settings"].tap()
        reveal("settings.privacyData").tap()
        XCTAssertTrue(app.navigationBars["Privacy & Data"].waitForExistence(timeout: 5))
        XCTAssertTrue(reveal("privacyData.deleteAll").isHittable)
        capture("Privacy destructive control")
        XCTAssertEqual(app.alerts.count, 0)
        XCTAssertEqual(XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.count, 0)
    }

    private func launch(fixture: String) {
        app.launchEnvironment["TRACKWORK_UI_TEST_FIXTURE"] = fixture
        app.launch()
        XCTAssertTrue(app.navigationBars["TrackWork"].waitForExistence(timeout: 8))
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @discardableResult
    private func reveal(_ identifier: String) -> XCUIElement {
        let target = element(identifier)
        for _ in 0..<16 {
            if target.exists && target.isHittable { return target }
            if target.exists && target.frame.minY < app.frame.midY {
                app.swipeDown()
            } else {
                app.swipeUp()
            }
        }
        XCTFail("Unable to reveal \(identifier)")
        return target
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Colour Refinement \(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
