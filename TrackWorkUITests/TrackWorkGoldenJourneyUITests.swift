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
        for tab in ["Summary", "Calendar", "History", "Insights", "Settings"] {
            XCTAssertTrue(app.tabBars.buttons[tab].exists, "Missing \(tab) tab")
        }

        app.tabBars.buttons["Settings"].tap()
        app.buttons["Location Setup"].tap()

        XCTAssertTrue(app.navigationBars["Location Setup"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Automatic Detection"].exists)
        XCTAssertTrue(app.staticTexts["Unavailable"].exists)
        XCTAssertEqual(app.alerts.count, 0)
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
        XCTAssertTrue(day.label.localizedCaseInsensitiveContains("Office"), day.label)

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
        XCTAssertTrue(day.label.localizedCaseInsensitiveContains("Annual leave"), day.label)
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
        XCTAssertTrue(day.label.localizedCaseInsensitiveContains("Custom exclusion"), day.label)
    }

    func testCSVAndPDFExportsCompleteWithoutSharingSensitiveRawData() {
        launch(fixture: "populated")

        app.tabBars.buttons["Insights"].tap()
        element(identifier: "insights.export").tap()
        XCTAssertTrue(app.navigationBars["Export"].waitForExistence(timeout: 5))

        revealButton(label: "Generate CSV").tap()
        let share = element(identifier: "export.share")
        XCTAssertTrue(share.waitForExistence(timeout: 8))
        XCTAssertTrue(share.label.localizedCaseInsensitiveContains("CSV"), share.label)

        revealButton(label: "Generate PDF").tap()
        XCTAssertTrue(waitUntil(timeout: 8) {
            self.element(identifier: "export.share").label.localizedCaseInsensitiveContains("PDF")
        })
    }

    func testConfirmedPrivacyResetRemovesSeededAttendance() {
        launch(fixture: "populated")

        app.tabBars.buttons["Calendar"].tap()
        let seededDay = calendarDayElement()
        XCTAssertTrue(seededDay.waitForExistence(timeout: 5))
        XCTAssertTrue(seededDay.label.localizedCaseInsensitiveContains("Office"), seededDay.label)

        app.tabBars.buttons["Settings"].tap()
        reveal(identifier: "settings.privacyData").tap()
        element(identifier: "privacyData.deleteAll").tap()
        let confirmation = element(identifier: "privacyData.confirmDeleteAll")
        XCTAssertTrue(confirmation.waitForExistence(timeout: 3))
        confirmation.tap()
        XCTAssertTrue(element(identifier: "privacyData.resetStatus").waitForExistence(timeout: 5))

        app.tabBars.buttons["Calendar"].tap()
        let resetDay = calendarDayElement()
        XCTAssertTrue(resetDay.waitForExistence(timeout: 5))
        XCTAssertTrue(resetDay.label.localizedCaseInsensitiveContains("Needs review"), resetDay.label)
    }

    private func launch(fixture: String) {
        app.launchEnvironment["TRACKWORK_UI_TESTING"] = "1"
        app.launchEnvironment["TRACKWORK_UI_TEST_FIXTURE"] = fixture
        app.launch()
    }

    private func openCalendarDay() {
        app.tabBars.buttons["Calendar"].tap()
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

        while calendar.isDateInWeekend(date), calendar.component(.month, from: date) == month {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: date) else {
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
}

private extension XCUIElement {
    var valueText: String {
        value as? String ?? ""
    }
}
