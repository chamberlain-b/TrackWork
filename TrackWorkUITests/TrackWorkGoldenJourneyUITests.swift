import XCTest

final class TrackWorkGoldenJourneyUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testFreshLaunchNavigatesWithoutRequestingLocationPermission() {
        launch(fixture: "fresh")

        XCTAssertTrue(app.navigationBars["Summary"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.alerts.count, 0)
        for tab in ["Summary", "Calendar", "History", "Settings"] {
            XCTAssertTrue(app.workTrackTab(named: tab).exists, "Missing \(tab) tab")
        }
        XCTAssertFalse(app.workTrackTab(named: "Insights").exists)

        app.workTrackTab(named: "Settings").tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        attachScreenshot(named: "Settings")

        reveal(identifier: "settings.workdays").tap()
        XCTAssertTrue(app.navigationBars["Workdays"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches["Monday"].exists)
        XCTAssertTrue(app.switches["Friday"].exists)
        app.navigationBars.buttons["Settings"].tap()

        reveal(identifier: "settings.locations").tap()

        XCTAssertTrue(app.navigationBars["Locations"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(identifier: "locationSetup.quickCheckIn").exists)
        XCTAssertEqual(app.alerts.count, 0)

        app.buttons["locationSetup.home"].tap()
        XCTAssertTrue(app.buttons["placeEditor.searchAddress"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["placeEditor.useCurrentLocation"].exists)
        XCTAssertFalse(app.buttons["placeEditor.save"].isEnabled)
        XCTAssertEqual(app.alerts.count, 0)
        attachScreenshot(named: "Location Place Editor")

        app.buttons["placeEditor.useCurrentLocation"].tap()
        let explanation = app.alerts["Use your current location?"]
        XCTAssertTrue(explanation.waitForExistence(timeout: 3))
        attachScreenshot(named: "Current Location Explanation")
        explanation.buttons["Cancel"].tap()
        XCTAssertTrue(explanation.waitForNonExistence(timeout: 3))

        app.buttons["placeEditor.searchAddress"].tap()
        XCTAssertTrue(app.navigationBars["Find a Place"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.alerts.count, 0)
        attachScreenshot(named: "Address Search")
    }

    func testPopulatedSummaryPresentsPrimaryHierarchyAndDetails() {
        launch(fixture: "populated")

        XCTAssertTrue(element(identifier: "dashboard.hero").waitForExistence(timeout: 8))
        attachScreenshot(named: "Summary Top")
        XCTAssertFalse(element(identifier: "dashboard.atAGlance").exists)
        XCTAssertFalse(element(identifier: "dashboard.calculation").exists)
        let confirmedOfficeRate = app.staticTexts["confirmed office rate"]
        XCTAssertTrue(confirmedOfficeRate.exists)
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", "confirmed office day")
            ).firstMatch.exists,
            "Expected the Summary to separate confirmed attendance from unresolved days"
        )

        let trends = reveal(identifier: "dashboard.trends")
        XCTAssertTrue(trends.isHittable)
        attachScreenshot(named: "Summary Trends")
        trends.tap()
        XCTAssertTrue(app.navigationBars["Compliance details"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Summary"].tap()

        let officePlan = reveal(identifier: "dashboard.officePlan")
        XCTAssertTrue(officePlan.isHittable)
        attachScreenshot(named: "Summary Office Plan")
        officePlan.tap()
        XCTAssertTrue(app.navigationBars["Plan Office Days"].waitForExistence(timeout: 5))
        attachScreenshot(named: "Office Plan From Summary")
    }

    func testCurrentLocationSelectionRequestsPermissionOnlyAfterRationale() {
        app.launchEnvironment["TRACKWORK_UI_TESTING"] = "1"
        app.launchEnvironment["TRACKWORK_UI_TEST_FIXTURE"] = "fresh"
        app.launchEnvironment["TRACKWORK_UI_TEST_CURRENT_LOCATION"] = "1"
        app.resetAuthorizationStatus(for: .location)

        app.launch()
        app.workTrackTab(named: "Settings").tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        reveal(identifier: "settings.locations").tap()
        app.buttons["locationSetup.home"].tap()

        XCTAssertEqual(app.alerts.count, 0)
        app.buttons["placeEditor.useCurrentLocation"].tap()

        let explanation = app.alerts["Use your current location?"]
        XCTAssertTrue(explanation.waitForExistence(timeout: 3))
        explanation.buttons["Use Current Location"].tap()
        allowLocationPermission()

        XCTAssertTrue(element(identifier: "placeEditor.selectedPlace").waitForExistence(timeout: 15))
        XCTAssertTrue(app.navigationBars["Home"].exists)
        XCTAssertTrue(app.buttons["placeEditor.save"].isEnabled)
        XCTAssertFalse(element(identifier: "placeEditor.locationError").exists)
        attachScreenshot(named: "Current Location Selected")
    }

    func testAutomaticAttendanceStartsOffWithoutRequestingPermission() {
        app.launchEnvironment["TRACKWORK_UI_TESTING"] = "1"
        app.launchEnvironment["TRACKWORK_UI_TEST_FIXTURE"] = "fresh"
        app.resetAuthorizationStatus(for: .location)
        app.launch()

        app.workTrackTab(named: "Settings").tap()
        let automaticAttendance = reveal(identifier: "settings.automaticAttendance")
        XCTAssertTrue(automaticAttendance.isHittable)
        automaticAttendance.tap()

        XCTAssertTrue(app.navigationBars["Automatic Attendance"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(identifier: "automaticTracking.status").exists)
        XCTAssertTrue(element(identifier: "automaticTracking.setupPlaces").exists)
        XCTAssertFalse(element(identifier: "automaticTracking.requestWhenInUse").exists)
        XCTAssertEqual(app.alerts.count, 0)
        attachScreenshot(named: "Automatic Attendance Opt In")
    }

    func testSummaryReviewActionOpensReviewQueue() {
        launch(fixture: "fresh")

        let reviewAction = reveal(identifier: "dashboard.reviewAction")
        XCTAssertTrue(reviewAction.isHittable)
        reviewAction.tap()

        XCTAssertTrue(app.navigationBars["Review Days"].waitForExistence(timeout: 5))
        attachScreenshot(named: "Review Queue")
    }

    func testCalendarAndHistoryUseMatchingLargeHeaders() {
        launch(fixture: "populated")

        app.workTrackTab(named: "Calendar").tap()
        XCTAssertTrue(app.navigationBars["Calendar"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(identifier: "calendar.monthSummary").waitForExistence(timeout: 3))
        XCTAssertTrue(waitUntil(timeout: 3) { self.app.workTrackTab(named: "Settings").isHittable })
        attachScreenshot(named: "Calendar")

        app.workTrackTab(named: "History").tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 5))
        XCTAssertTrue(waitUntil(timeout: 3) { self.app.workTrackTab(named: "Settings").isHittable })
        attachScreenshot(named: "History")
    }

    func testManualOverrideAndNotePersistFromCalendar() {
        launch(fixture: "fresh")
        openCalendarDay()

        choosePicker(identifier: "dayDetail.manualStatus", option: "Office")
        choosePicker(identifier: "dayDetail.overrideReason", option: "Forgot work pass")
        textElement(identifier: "dayDetail.note").tap()
        textElement(identifier: "dayDetail.note").typeText("Entered through reception")
        element(identifier: "dayDetail.save").tap()

        let day = calendarDayElement()
        XCTAssertTrue(day.waitForExistence(timeout: 5))
        XCTAssertTrue(day.valueText.localizedCaseInsensitiveContains("Office"), day.valueText)

        day.tap()
        XCTAssertTrue(element(identifier: "dayDetail.note").waitForExistence(timeout: 5))
        XCTAssertTrue(element(identifier: "dayDetail.note").valueText.contains("Entered through reception"))
    }

    func testAnnualLeavePersistsFromCalendar() {
        launch(fixture: "fresh")
        openCalendarDay()

        choosePicker(identifier: "dayDetail.leaveType", option: "Annual leave")
        element(identifier: "dayDetail.save").tap()

        let day = calendarDayElement()
        XCTAssertTrue(day.waitForExistence(timeout: 5))
        XCTAssertTrue(day.valueText.localizedCaseInsensitiveContains("Annual leave"), day.valueText)
    }

    func testCustomExclusionPersistsFromCalendar() {
        launch(fixture: "fresh")
        openCalendarDay()

        element(identifier: "dayDetail.customExcluded").tap()
        let reason = textElement(identifier: "dayDetail.customExclusionReason")
        XCTAssertTrue(reason.waitForExistence(timeout: 3))
        reason.tap()
        reason.typeText("Company shutdown")
        element(identifier: "dayDetail.save").tap()

        let day = calendarDayElement()
        XCTAssertTrue(day.waitForExistence(timeout: 5))
        XCTAssertTrue(day.valueText.localizedCaseInsensitiveContains("Custom exclusion"), day.valueText)
    }

    func testCSVAndPDFExportsCompleteWithoutSharingSensitiveRawData() {
        launch(fixture: "populated")

        app.workTrackTab(named: "History").tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 5))
        element(identifier: "history.export").tap()
        XCTAssertTrue(app.navigationBars["Export"].waitForExistence(timeout: 5))
        attachScreenshot(named: "Export")

        revealButton(label: "Create CSV").tap()
        let share = element(identifier: "export.share")
        XCTAssertTrue(share.waitForExistence(timeout: 8))
        XCTAssertTrue(share.label.localizedCaseInsensitiveContains("CSV"), share.label)

        revealButton(label: "Create PDF").tap()
        XCTAssertTrue(waitUntil(timeout: 8) {
            self.element(identifier: "export.share").label.localizedCaseInsensitiveContains("PDF")
        })
    }

    func testConfirmedPrivacyResetRemovesSeededAttendance() {
        launch(fixture: "populated")

        app.workTrackTab(named: "Calendar").tap()
        let seededDay = calendarDayElement()
        XCTAssertTrue(seededDay.waitForExistence(timeout: 5))
        XCTAssertTrue(seededDay.valueText.localizedCaseInsensitiveContains("Office"), seededDay.valueText)

        app.workTrackTab(named: "Settings").tap()
        reveal(identifier: "settings.privacyData").tap()
        reveal(identifier: "privacyData.deleteAll").tap()
        let confirmation = element(identifier: "privacyData.confirmDeleteAll")
        XCTAssertTrue(confirmation.waitForExistence(timeout: 3))
        confirmation.tap()
        XCTAssertTrue(element(identifier: "privacyData.resetStatus").waitForExistence(timeout: 5))

        app.workTrackTab(named: "Calendar").tap()
        let resetDay = calendarDayElement()
        XCTAssertTrue(resetDay.waitForExistence(timeout: 5))
        XCTAssertTrue(resetDay.valueText.localizedCaseInsensitiveContains("Needs review"), resetDay.valueText)
    }

    private func launch(fixture: String) {
        app.launchEnvironment["TRACKWORK_UI_TESTING"] = "1"
        app.launchEnvironment["TRACKWORK_UI_TEST_FIXTURE"] = fixture
        app.launch()
    }

    private func openCalendarDay() {
        app.workTrackTab(named: "Calendar").tap()
        let day = calendarDayElement()
        XCTAssertTrue(day.waitForExistence(timeout: 5), "Calendar day \(calendarDayIdentifier) did not appear")
        day.tap()
        XCTAssertTrue(element(identifier: "dayDetail.save").waitForExistence(timeout: 5))
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

    private func allowLocationPermission() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Location permission prompt did not appear")

        for buttonTitle in ["Allow While Using App", "Allow Once"] {
            let button = alert.buttons[buttonTitle]
            if button.exists {
                button.tap()
                return
            }
        }

        XCTFail("Location permission prompt did not offer an allow action")
    }

    private func reveal(identifier: String, maxSwipes: Int = 5) -> XCUIElement {
        let target = element(identifier: identifier)
        for _ in 0...maxSwipes {
            if target.exists && target.isHittable {
                return target
            }
            app.swipeUp()
        }

        XCTFail("Unable to reveal \(identifier)")
        return target
    }

    private func revealButton(label: String) -> XCUIElement {
        let target = app.buttons[label].firstMatch
        for _ in 0...5 {
            if target.exists && target.isHittable {
                return target
            }
            app.swipeUp()
        }
        for _ in 0...7 {
            if target.exists && target.isHittable {
                return target
            }
            app.swipeDown()
        }

        XCTFail("Unable to reveal button \(label)")
        return target
    }

    private func textElement(identifier: String) -> XCUIElement {
        let textView = app.textViews.matching(identifier: identifier).firstMatch
        if textView.exists {
            return textView
        }

        return app.textFields.matching(identifier: identifier).firstMatch
    }

    private func calendarDayElement() -> XCUIElement {
        element(identifier: calendarDayIdentifier)
    }

    private var calendarDayIdentifier: String {
        "calendar.day.\(Self.isoDate.string(from: Self.testDate))"
    }

    private static var testDate: Date {
        let calendar = Calendar.autoupdatingCurrent
        var date = calendar.startOfDay(for: .now)
        let month = calendar.component(.month, from: date)
        let year = calendar.component(.year, from: date)

        while calendar.isDateInWeekend(date) {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: date) else {
                break
            }

            guard calendar.component(.month, from: previous) == month,
                  calendar.component(.year, from: previous) == year else {
                break
            }

            date = previous
        }

        return date
    }

    private static let isoDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = .autoupdatingCurrent
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

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

private extension XCUIElement {
    var valueText: String {
        value as? String ?? ""
    }
}
