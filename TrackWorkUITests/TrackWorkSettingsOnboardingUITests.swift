import XCTest

/// Policy setup uses isolated SwiftData fixtures while exercising production holiday startup.
final class TrackWorkSettingsOnboardingUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["TRACKWORK_UI_TESTING"] = "1"
        app.launchEnvironment["TRACKWORK_UI_TEST_FIXTURE"] = "firstLaunch"
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    func testFirstLaunchCancelAndBackDoNotCreatePolicy() {
        launch()
        XCTAssertTrue(text(containing: "Set your office target").exists)
        assertNoPermissionPrompt()
        openSettings()
        XCTAssertEqual(element("settings.editPolicy").label, "Set Up Work Policy")
        capture("Unconfigured Settings")

        for _ in 0..<2 {
            openPolicy()
            replaceText("settings.fixedRequiredDays", with: "6")
            reveal("settings.workdays").tap()
            XCTAssertTrue(app.navigationBars["Workdays"].waitForExistence(timeout: 5))
            setSwitch("Friday", enabled: false)
            goBack(from: "Workdays", to: "Set Up Work Policy")
            XCTAssertEqual(field("settings.fixedRequiredDays").value as? String, "6")
            element("settings.cancelPolicy").tap()
            XCTAssertTrue(element("settings.editPolicy").waitForExistence(timeout: 5))
            XCTAssertEqual(element("settings.editPolicy").label, "Set Up Work Policy")
            app.workTrackTab(named: "Home").tap()
            XCTAssertTrue(text(containing: "Set your office target").exists)
            XCTAssertFalse(element("today.progressDetail").exists)
            openSettings()
        }

        openPolicy()
        XCTAssertEqual(field("settings.fixedRequiredDays").value as? String, "10")
        reveal("settings.workdays").tap()
        XCTAssertEqual(app.switches["Friday"].value as? String, "1")
        assertNoPermissionPrompt()
        capture("Setup workdays remain a draft")
    }

    func testManualPolicyConfirmationUpdatesHomeWithoutPermissions() {
        launch()
        openSettings()
        openPolicy()
        replaceText("settings.fixedRequiredDays", with: "6")
        choose("settings.jurisdiction", option: "New South Wales")
        XCTAssertTrue(reveal("settings.policyEffectiveDate").exists)
        capture("First policy confirmation")
        savePolicy()
        XCTAssertEqual(element("settings.editPolicy").label, "Edit Work Policy")
        assertNoPermissionPrompt()

        app.workTrackTab(named: "Home").tap()
        XCTAssertTrue(element("today.progressDetail").waitForExistence(timeout: 5))
        XCTAssertEqual(element("today.progressDetail").label, "0 of 6 office days recorded")
        XCTAssertFalse(text(containing: "Set your office target").exists)
        capture("Manual setup Home")
        reveal("today.correct").tap()
        XCTAssertTrue(element("dayDetail.save").waitForExistence(timeout: 5))
        choose("dayDetail.manualStatus", option: "Office")
        element("dayDetail.save").tap()
        XCTAssertTrue(element("today.status").waitForExistence(timeout: 5))
        XCTAssertEqual(element("today.status").label, "Office")
        assertNoPermissionPrompt()
        capture("Attendance recorded manually without locations")
        openSettings()
        reveal("settings.locations").tap()
        XCTAssertTrue(app.navigationBars["Locations"].waitForExistence(timeout: 5))
        XCTAssertFalse(element("locationSetup.quickCheckIn").exists)
        XCTAssertTrue(element("locationSetup.manualAttendance").exists)
        capture("Optional locations")
        assertNoPermissionPrompt()
    }

    func testExistingPolicyUpgradeEditPreservesPreviousMonthAndAttendance() {
        launch(fixture: "existingPolicyUpgrade")
        XCTAssertFalse(text(containing: "Set your office target").exists)
        XCTAssertTrue(element("today.progressDetail").label.contains("of 7 office days recorded"))
        let previousMonth = previousMonthTarget()
        XCTAssertTrue(previousMonth.contains("of 7 office days recorded"), previousMonth)
        openSettings()
        XCTAssertEqual(element("settings.editPolicy").label, "Edit Work Policy")
        capture("Existing policy retained")
        openPolicy()
        XCTAssertEqual(field("settings.fixedRequiredDays").value as? String, "7")
        XCTAssertTrue(reveal("settings.jurisdiction").label.contains("New South Wales"))
        reveal("settings.workdays").tap()
        XCTAssertEqual(app.switches["Thursday"].value as? String, "1")
        XCTAssertEqual(app.switches["Friday"].value as? String, "0")
        goBack(from: "Workdays", to: "Work Policy")
        replaceText("settings.fixedRequiredDays", with: "12")
        element("settings.cancelPolicy").tap()
        openPolicy()
        XCTAssertEqual(field("settings.fixedRequiredDays").value as? String, "7")
        replaceText("settings.fixedRequiredDays", with: "9")
        XCTAssertTrue(reveal("settings.policyEffectiveDate").exists)
        capture("Existing policy effective date")
        savePolicy()

        app.workTrackTab(named: "Home").tap()
        XCTAssertTrue(element("today.progressDetail").label.contains("of 9 office days recorded"))
        XCTAssertEqual(previousMonthTarget(), previousMonth, "Changing this month must preserve the prior policy")
        app.workTrackTab(named: "Home").tap()
        reveal("today.correct").tap()
        XCTAssertTrue(element("dayDetail.note").waitForExistence(timeout: 5))
        XCTAssertTrue((element("dayDetail.note").value as? String ?? "").contains("Existing attendance note"))
        assertNoPermissionPrompt()
        capture("Existing attendance preserved")
    }

    func testSaveFailureKeepsDraftAndCanRetry() {
        app.launchEnvironment["TRACKWORK_UI_POLICY_SAVE_FAILURE"] = "once"
        launch()
        openSettings()
        openPolicy()
        replaceText("settings.fixedRequiredDays", with: "7")
        element("settings.savePolicy").tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.buttons["Retry"].exists)
        XCTAssertTrue(alert.buttons["Keep Editing"].exists)
        XCTAssertTrue(alert.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Your changes are still in this draft")).firstMatch.exists)
        capture("Recoverable save error")
        alert.buttons["Keep Editing"].tap()
        XCTAssertEqual(field("settings.fixedRequiredDays").value as? String, "7")
        XCTAssertTrue(reveal("settings.policySaveError").exists)
        capture("Draft retained after save error")
        savePolicy()
        app.workTrackTab(named: "Home").tap()
        XCTAssertEqual(element("today.progressDetail").label, "0 of 7 office days recorded")
        assertNoPermissionPrompt()
    }

    func testConsecutiveSameMonthEditsRefreshHomeAndInsightsImmediately() {
        launch(fixture: "existingPolicyUpgrade")
        let originalPreviousMonth = previousMonthTarget()
        for target in [9, 11] {
            openSettings()
            openPolicy()
            replaceText("settings.fixedRequiredDays", with: String(target))
            savePolicy()
            app.workTrackTab(named: "Home").tap()
            let homeProgress = element("today.progressDetail").label
            XCTAssertTrue(homeProgress.contains("of \(target) office days recorded"), homeProgress)
            app.workTrackTab(named: "Insights").tap()
            choose("insights.periodPreset", option: "Current month")
            let count = element("insights.targetCount")
            let insightsProgress = count.value as? String ?? count.label
            XCTAssertTrue(insightsProgress.contains("of \(target) office days recorded"), insightsProgress)
            XCTAssertEqual(previousMonthTarget(), originalPreviousMonth)
        }
        capture("Consecutive edits preserve previous month")
    }

    func testSaveFailureRetryActionCompletesConfirmation() {
        app.launchEnvironment["TRACKWORK_UI_POLICY_SAVE_FAILURE"] = "once"
        launch()
        openSettings()
        openPolicy()
        replaceText("settings.fixedRequiredDays", with: "4")
        element("settings.savePolicy").tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Retry"].firstMatch.tap()
        XCTAssertTrue(element("settings.editPolicy").waitForExistence(timeout: 5))
        XCTAssertEqual(element("settings.editPolicy").label, "Edit Work Policy")
        app.workTrackTab(named: "Home").tap()
        XCTAssertEqual(element("today.progressDetail").label, "0 of 4 office days recorded")
    }

    func testInvalidPercentageStaysDraftAndExplicitZeroIsConfigured() {
        launch()
        openSettings()
        openPolicy()
        choose("settings.requirementType", option: "Percentage of workdays")
        replaceText("settings.requiredPercentage", with: "101")
        element("settings.savePolicy").tap()
        XCTAssertTrue(reveal("settings.policyValidation").exists)
        XCTAssertTrue(element("settings.cancelPolicy").exists)
        capture("Invalid policy value")
        replaceText("settings.requiredPercentage", with: "0")
        savePolicy()
        XCTAssertEqual(element("settings.editPolicy").label, "Edit Work Policy")
        app.workTrackTab(named: "Home").tap()
        XCTAssertFalse(text(containing: "Set your office target").exists)
        app.workTrackTab(named: "Insights").tap()
        XCTAssertTrue(element("insights.targetStatus").waitForExistence(timeout: 5))
        XCTAssertFalse(element("insights.targetStatus").label.contains("Choose an office target"))
        capture("Explicit zero target")
    }

    func testBlankNumericValidationReturnsToVisibleErrorOnEverySave() {
        launch()
        openSettings()
        openPolicy()
        replaceText("settings.minimumOfficeMinutes", with: "")
        element("settings.savePolicy").tap()
        XCTAssertTrue(element("settings.policyValidation").waitForExistence(timeout: 5))
        XCTAssertTrue(element("settings.policyValidation").isHittable,
                      "Saving an invalid value at the bottom should reveal the validation message")
        capture("Blank minimum time validation")

        reveal("settings.minimumOfficeMinutes")
        element("settings.savePolicy").tap()
        XCTAssertTrue(element("settings.policyValidation").isHittable,
                      "Repeating the same invalid Save must reveal the existing message again")
        replaceText("settings.minimumOfficeMinutes", with: "180")
        savePolicy()
        XCTAssertEqual(element("settings.editPolicy").label, "Edit Work Policy")
        assertNoPermissionPrompt()
    }

    /// The caller selects the simulator appearance; screenshots therefore show actual light or dark mode.
    func testSettingsVisualEvidenceInCurrentAppearance() {
        launch(fixture: "existingPolicyUpgrade")
        openSettings()
        XCTAssertTrue(element("settings.editPolicy").isHittable)
        XCTAssertTrue(element("settings.automaticAttendance").isHittable)
        XCTAssertLessThan(element("settings.editPolicy").frame.minY,
                          element("settings.automaticAttendance").frame.minY)
        capture("Settings policy first")
        openPolicy()
        capture("Work Policy target")
        reveal("settings.jurisdiction")
        capture("Work Policy workdays and holidays")
        reveal("settings.minimumOfficeMinutes")
        capture("Work Policy office time and effective date")
        element("settings.cancelPolicy").tap()
        reveal("settings.automaticAttendance").tap()
        XCTAssertTrue(app.navigationBars["Automatic Attendance"].waitForExistence(timeout: 5))
        capture("Optional Automatic Attendance")
        assertNoPermissionPrompt()
    }

    func testLargestTextKeepsPolicyControlsAndSaveReachable() {
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        launch()
        openSettings()
        XCTAssertTrue(reveal("settings.editPolicy").isHittable)
        capture("Largest text setup")
        openPolicy()
        XCTAssertTrue(reveal("settings.fixedRequiredDays").isHittable)
        capture("Largest text policy target")
        reveal("settings.workdays").tap()
        XCTAssertTrue(app.navigationBars["Workdays"].waitForExistence(timeout: 5))
        capture("Largest text workdays")
        goBack(from: "Workdays", to: "Set Up Work Policy")
        XCTAssertTrue(reveal("settings.jurisdiction").isHittable)
        capture("Largest text holiday region")
        XCTAssertTrue(reveal("settings.minimumOfficeMinutes").isHittable)
        capture("Largest text office time")
        XCTAssertTrue(reveal("settings.policyEffectiveDate").isHittable)
        capture("Largest text effective date")
        XCTAssertTrue(element("settings.savePolicy").isHittable)
        savePolicy()
        assertNoPermissionPrompt()
    }

    private func launch(fixture: String = "firstLaunch") {
        app.launchEnvironment["TRACKWORK_UI_TEST_FIXTURE"] = fixture
        app.launch()
        XCTAssertTrue(app.navigationBars["TrackWork"].waitForExistence(timeout: 8))
    }

    private func openSettings() {
        app.workTrackTab(named: "Settings").tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        reveal("settings.editPolicy")
    }

    private func openPolicy() {
        reveal("settings.editPolicy").tap()
        XCTAssertTrue(element("settings.cancelPolicy").waitForExistence(timeout: 5))
        XCTAssertTrue(element("settings.savePolicy").exists)
    }

    private func savePolicy() {
        element("settings.savePolicy").tap()
        XCTAssertTrue(element("settings.cancelPolicy").waitForNonExistence(timeout: 5))
        XCTAssertTrue(element("settings.editPolicy").waitForExistence(timeout: 5))
    }

    private func previousMonthTarget() -> String {
        app.workTrackTab(named: "Insights").tap()
        XCTAssertTrue(app.navigationBars["Insights"].waitForExistence(timeout: 5))
        choose("insights.periodPreset", option: "Previous month")
        let count = element("insights.targetCount")
        XCTAssertTrue(count.waitForExistence(timeout: 5))
        return count.value as? String ?? count.label
    }

    private func goBack(from title: String, to previousTitle: String) {
        let bar = app.navigationBars[title]
        let namedBack = bar.buttons[previousTitle]
        if namedBack.exists {
            namedBack.tap()
        } else {
            bar.buttons.element(boundBy: 0).tap()
        }
        XCTAssertTrue(element("settings.savePolicy").waitForExistence(timeout: 5))
    }

    private func setSwitch(_ label: String, enabled: Bool) {
        let toggle = app.switches[label]
        XCTAssertTrue(toggle.exists)
        if (toggle.value as? String == "1") != enabled {
            toggle.tap()
        }
    }

    private func replaceText(_ identifier: String, with value: String) {
        reveal(identifier)
        let textField = field(identifier)
        XCTAssertTrue(textField.exists, "Missing text field \(identifier)")
        // Native LabeledContent exposes the entire row as the field's accessibility frame.
        // The editable numeric value occupies its trailing edge; the leading label is not editable.
        let horizontalTarget = identifier == "settings.minimumOfficeMinutes" ? 0.5 : 0.995
        textField.coordinate(withNormalizedOffset: CGVector(dx: horizontalTarget, dy: 0.5)).tap()
        let existing = textField.value as? String ?? ""
        textField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count) + value)
        let done = app.buttons["Done"].firstMatch
        if app.keyboards.count > 0 && done.exists && done.isHittable { done.tap() }
        let enteredValue = textField.value as? String ?? ""
        if value.isEmpty {
            XCTAssertTrue(enteredValue.isEmpty || enteredValue == textField.placeholderValue,
                          "The draft field should be empty, got \(enteredValue)")
        } else {
            XCTAssertEqual(enteredValue, value, "Numeric draft replacement must succeed before saving")
        }
    }

    private func field(_ identifier: String) -> XCUIElement {
        let direct = app.textFields[identifier]
        if direct.exists { return direct }
        return element(identifier).textFields.firstMatch
    }

    private func choose(_ identifier: String, option: String) {
        reveal(identifier).tap()
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
        XCTAssertTrue(item.exists && item.isHittable, "Missing picker option \(option)")
        item.tap()
    }

    @discardableResult
    private func reveal(_ identifier: String) -> XCUIElement {
        let target = element(identifier)
        let topOfForm = ["settings.editPolicy", "settings.policyEffectiveDate",
                         "settings.policyValidation", "settings.policySaveError"].contains(identifier)
        for _ in 0..<18 {
            if target.exists && target.isHittable { return target }
            if (!target.exists && topOfForm) || (target.exists && target.frame.minY < app.frame.midY) {
                app.swipeDown()
            } else {
                app.swipeUp()
            }
        }
        XCTFail("Unable to reveal \(identifier)")
        return target
    }

    private func element(_ identifier: String) -> XCUIElement {
        if identifier == "settings.editPolicy" { return app.buttons[identifier].firstMatch }
        return app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func text(containing value: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", value)).firstMatch
    }

    private func assertNoPermissionPrompt() {
        XCTAssertEqual(app.alerts.count, 0)
        XCTAssertEqual(XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.count, 0,
                       "Manual policy setup must not request OS permissions")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Settings Onboarding \(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

/// Select this class separately after uninstalling TrackWork from the dedicated test simulator.
/// It deliberately uses the production on-disk store and has no UI-test launch environment.
final class TrackWorkSettingsProductionLaunchUITests: XCTestCase {
    func testGenuineProductionFirstLaunchPersistence() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment = [:]
        app.launchArguments = []
        defer { app.terminate() }
        app.launch()
        XCTAssertTrue(app.navigationBars["TrackWork"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Set your office target"].exists,
                      "This test requires a newly installed app on the isolated simulator")
        XCTAssertEqual(XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.count, 0)
        app.workTrackTab(named: "Settings").tap()
        let editPolicy = app.buttons["settings.editPolicy"]
        XCTAssertTrue(editPolicy.waitForExistence(timeout: 5))
        XCTAssertEqual(editPolicy.label, "Set Up Work Policy")
        editPolicy.tap()
        let target = app.textFields["settings.fixedRequiredDays"]
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        target.coordinate(withNormalizedOffset: CGVector(dx: 0.995, dy: 0.5)).tap()
        let original = target.value as? String ?? ""
        target.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: original.count) + "6")
        XCTAssertEqual(target.value as? String, "6", "Replace the draft before confirming the production policy")
        app.buttons["settings.savePolicy"].tap()
        XCTAssertTrue(app.buttons["settings.cancelPolicy"].waitForNonExistence(timeout: 5))
        XCTAssertEqual(editPolicy.label, "Edit Work Policy")
        capture(app, name: "Production first policy saved")
        app.terminate()

        app.launch()
        XCTAssertTrue(app.navigationBars["TrackWork"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["Set your office target"].exists)
        let progress = app.descendants(matching: .any).matching(identifier: "today.progressDetail").firstMatch
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        XCTAssertEqual(progress.label, "0 of 6 office days recorded")
        app.workTrackTab(named: "Settings").tap()
        XCTAssertEqual(editPolicy.label, "Edit Work Policy")
        editPolicy.tap()
        XCTAssertEqual(target.value as? String, "6")
        XCTAssertEqual(XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.count, 0)
        capture(app, name: "Production policy retained after relaunch")
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Settings Onboarding \(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
