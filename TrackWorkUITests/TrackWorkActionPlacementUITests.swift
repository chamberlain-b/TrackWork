import XCTest

final class TrackWorkActionPlacementUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testPlanningAndCheckInUseContextualNavigationActions() {
        launchPopulatedFixture()

        let checkIn = element(identifier: "dashboard.quickCheckIn")
        XCTAssertTrue(checkIn.waitForExistence(timeout: 5))
        XCTAssertTrue(checkIn.isHittable)
        attachScreenshot(named: "Summary Contextual Check In")
        checkIn.tap()
        XCTAssertTrue(app.navigationBars["Check In"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Summary"].tap()

        app.tabBars.buttons["Calendar"].tap()
        let actions = element(identifier: "calendar.actions")
        XCTAssertTrue(actions.waitForExistence(timeout: 5))
        XCTAssertTrue(actions.isHittable)
        verifyPlannedDayIfAvailable()
        actions.tap()
        attachScreenshot(named: "Calendar Add Menu")

        let planOfficeDays = element(identifier: "calendar.officePlan")
        XCTAssertTrue(planOfficeDays.waitForExistence(timeout: 3))
        planOfficeDays.tap()
        XCTAssertTrue(app.navigationBars["Plan Office Days"].waitForExistence(timeout: 5))
        if let plannedDateLabel = Self.plannedOfficeDateLabel {
            XCTAssertTrue(app.staticTexts[plannedDateLabel].waitForExistence(timeout: 3))
        }
        attachScreenshot(named: "Plan Office Days")
    }

    private func launchPopulatedFixture() {
        app.launchEnvironment["TRACKWORK_UI_TESTING"] = "1"
        app.launchEnvironment["TRACKWORK_UI_TEST_FIXTURE"] = "populated"
        app.launch()
    }

    private func verifyPlannedDayIfAvailable() {
        guard let identifier = Self.plannedOfficeDayIdentifier else { return }

        let plannedDay = element(identifier: identifier)
        XCTAssertTrue(plannedDay.waitForExistence(timeout: 3))
        let value = plannedDay.value as? String ?? ""
        XCTAssertTrue(value.localizedCaseInsensitiveContains("Planned office day"))
    }

    private func element(identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private static var plannedOfficeDate: Date? {
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: .now)
        let month = calendar.component(.month, from: today)
        let year = calendar.component(.year, from: today)
        var candidate = calendar.date(byAdding: .day, value: 1, to: today)

        while let date = candidate,
              calendar.component(.month, from: date) == month,
              calendar.component(.year, from: date) == year {
            if (2...6).contains(calendar.component(.weekday, from: date)) {
                return date
            }
            candidate = calendar.date(byAdding: .day, value: 1, to: date)
        }

        return nil
    }

    private static var plannedOfficeDayIdentifier: String? {
        plannedOfficeDate.map { "calendar.day.\(isoDate.string(from: $0))" }
    }

    private static var plannedOfficeDateLabel: String? {
        plannedOfficeDate?.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    private static let isoDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = .autoupdatingCurrent
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private func attachScreenshot(named name: String) {
        Thread.sleep(forTimeInterval: 0.6)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
