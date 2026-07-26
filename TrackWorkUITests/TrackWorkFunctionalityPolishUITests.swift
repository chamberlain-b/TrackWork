import XCTest

final class TrackWorkFunctionalityPolishUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["TRACKWORK_UI_TESTING"] = "1"
        app.launchEnvironment["TRACKWORK_UI_TEST_FIXTURE"] = "fresh"
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testReviewQueueQuickOfficeActionRecordsNextDay() throws {
        let reviewAction = reveal(identifier: "dashboard.reviewAction")
        XCTAssertTrue(reviewAction.isHittable)
        reviewAction.tap()

        XCTAssertTrue(app.navigationBars["Review Days"].waitForExistence(timeout: 5))

        let remaining = element(identifier: "reviewQueue.remaining")
        XCTAssertTrue(remaining.waitForExistence(timeout: 3))
        let initialCount = try XCTUnwrap(leadingInteger(in: remaining.label))

        let markOffice = element(identifier: "reviewQueue.markOffice")
        XCTAssertTrue(markOffice.isHittable)
        markOffice.tap()

        XCTAssertTrue(waitUntil(timeout: 5) {
            self.leadingInteger(in: remaining.label) == initialCount - 1
        })
        let undo = element(identifier: "reviewQueue.undo")
        XCTAssertTrue(undo.waitForExistence(timeout: 3))
        undo.tap()
        XCTAssertTrue(waitUntil(timeout: 5) {
            self.leadingInteger(in: remaining.label) == initialCount
        })
        XCTAssertEqual(app.alerts.count, 0)
        attachScreenshot(named: "Review Queue After Undo")
    }

    func testReviewQueueBatchRequiresSelectionAndConfirmation() throws {
        reveal(identifier: "dashboard.reviewAction").tap()
        XCTAssertTrue(app.navigationBars["Review Days"].waitForExistence(timeout: 5))

        let remaining = element(identifier: "reviewQueue.remaining")
        XCTAssertTrue(remaining.waitForExistence(timeout: 3))
        let initialCount = try XCTUnwrap(leadingInteger(in: remaining.label))

        element(identifier: "reviewQueue.select").tap()
        let markOffice = element(identifier: "reviewQueue.markSelectedOffice")
        XCTAssertTrue(markOffice.waitForExistence(timeout: 3))
        XCTAssertFalse(markOffice.isEnabled)

        element(identifier: "reviewQueue.selectWeek").tap()
        let selectionSummary = element(identifier: "reviewQueue.selectionSummary")
        XCTAssertTrue(selectionSummary.waitForExistence(timeout: 3))
        let selectedCount = try XCTUnwrap(leadingInteger(in: selectionSummary.label))
        XCTAssertGreaterThan(selectedCount, 0)
        XCTAssertTrue(markOffice.isEnabled)

        markOffice.tap()
        let confirm = element(identifier: "reviewQueue.confirmBatch")
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        attachScreenshot(named: "Review Queue Batch Confirmation")
        confirm.tap()

        XCTAssertTrue(waitUntil(timeout: 5) {
            self.leadingInteger(in: remaining.label) == initialCount - selectedCount
        })
        XCTAssertTrue(element(identifier: "reviewQueue.undo").exists)
    }

    func testCalendarSupportsSelectableAgendaAlternative() {
        app.workTrackTab(named: "Calendar").tap()
        XCTAssertTrue(app.navigationBars["Calendar"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(identifier: "calendar.monthGrid").waitForExistence(timeout: 3))

        app.buttons["Agenda"].tap()
        XCTAssertTrue(element(identifier: "calendar.agenda").waitForExistence(timeout: 3))
        XCTAssertFalse(element(identifier: "calendar.monthGrid").exists)
        attachScreenshot(named: "Calendar Agenda")
    }

    func testSettingsClarifiesSetupPreferredDaysAndLocationHierarchy() {
        app.workTrackTab(named: "Settings").tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(identifier: "settings.setupSummary").waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Days per month"].exists)
        XCTAssertFalse(app.staticTexts["Days per period"].exists)
        XCTAssertFalse(app.staticTexts["Location Events"].exists)

        reveal(identifier: "settings.preferredOfficeDays").tap()
        XCTAssertTrue(app.navigationBars["Preferred Office Days"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches["Tuesday"].exists)
        XCTAssertTrue(app.switches["Thursday"].exists)
        app.switches["Tuesday"].tap()
        app.navigationBars.buttons["Settings"].tap()

        let preferredDays = reveal(identifier: "settings.preferredOfficeDays")
        XCTAssertTrue(preferredDays.label.contains("Preferred office days"))

        reveal(identifier: "settings.automaticAttendance").tap()
        XCTAssertTrue(app.navigationBars["Automatic Attendance"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(identifier: "automaticTracking.events").exists)
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

    private func leadingInteger(in value: String) -> Int? {
        value.split(separator: " ").first.flatMap { Int($0) }
    }

    private func waitUntil(timeout: TimeInterval, condition: @escaping () -> Bool) -> Bool {
        let predicate = NSPredicate { _, _ in condition() }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
