import SwiftData
import XCTest
@testable import TrackWork

final class ComplianceRuleResolverTests: XCTestCase {
    private let resolver = ComplianceRuleResolver()
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    func testLegacyRuleRemainsActiveBeforeFirstEffectiveDatedRule() {
        let legacy = ComplianceRule(name: "Legacy", fixedRequiredDays: 8)
        let julyRule = ComplianceRule(
            name: "July",
            fixedRequiredDays: 10,
            effectiveFrom: date(2026, 7, 1)
        )

        XCTAssertTrue(resolver.rule(for: date(2026, 6, 30), from: [julyRule, legacy]) === legacy)
        XCTAssertTrue(resolver.rule(for: date(2026, 7, 1), from: [legacy, julyRule]) === julyRule)
    }

    func testLatestEffectiveRuleWinsForLaterPeriods() {
        let legacy = ComplianceRule(name: "Legacy", fixedRequiredDays: 8)
        let julyRule = ComplianceRule(
            name: "July",
            fixedRequiredDays: 10,
            effectiveFrom: date(2026, 7, 1)
        )
        let octoberRule = ComplianceRule(
            name: "October",
            fixedRequiredDays: 12,
            effectiveFrom: date(2026, 10, 1)
        )

        XCTAssertTrue(
            resolver.rule(for: date(2026, 12, 1), from: [octoberRule, legacy, julyRule]) === octoberRule
        )
    }

    func testCopyPreservesRuleValuesAndAddsEffectiveDate() {
        let original = ComplianceRule(
            name: "Hybrid rule",
            country: .newZealand,
            jurisdictionId: "NZ-AUCKLAND",
            requirementType: .percentageOfEligibleDays,
            fixedRequiredDays: nil,
            requiredPercentage: 0.6,
            prorateFixedTargetForLeave: false,
            minimumOfficeMinutes: 240,
            selectedISOWeekdays: [1, 2, 3, 4],
            preferredOfficeISOWeekdays: [2, 4]
        )
        let effectiveFrom = date(2026, 7, 1)

        let copy = resolver.copy(original, effectiveFrom: effectiveFrom, now: date(2026, 7, 12))

        XCTAssertEqual(copy.country, .newZealand)
        XCTAssertEqual(copy.jurisdictionId, "NZ-AUCKLAND")
        XCTAssertEqual(copy.requirementType, .percentageOfEligibleDays)
        XCTAssertEqual(copy.requiredPercentage, 0.6)
        XCTAssertEqual(copy.minimumOfficeMinutes, 240)
        XCTAssertEqual(copy.selectedISOWeekdays, [1, 2, 3, 4])
        XCTAssertEqual(copy.preferredOfficeISOWeekdays, [2, 4])
        XCTAssertEqual(copy.effectiveFrom, effectiveFrom)
    }

    func testLatestUpdatedRuleWinsWhenEffectiveDatesMatch() {
        let earlierUpdatedRule = ComplianceRule(
            name: "Earlier edit",
            fixedRequiredDays: 8,
            effectiveFrom: date(2026, 7, 1),
            updatedAt: date(2026, 7, 2)
        )
        let laterUpdatedRule = ComplianceRule(
            name: "Later edit",
            fixedRequiredDays: 11,
            effectiveFrom: date(2026, 7, 1),
            updatedAt: date(2026, 7, 3)
        )

        XCTAssertTrue(
            resolver.rule(
                for: date(2026, 7, 15),
                from: [laterUpdatedRule, earlierUpdatedRule]
            ) === laterUpdatedRule
        )
        XCTAssertTrue(
            resolver.rule(
                for: date(2026, 7, 15),
                from: [earlierUpdatedRule, laterUpdatedRule]
            ) === laterUpdatedRule
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}

@MainActor
final class WorkPolicyEditorTests: XCTestCase {
    private enum SaveFailure: Error { case unavailable }
    private let resolver = ComplianceRuleResolver()
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    func testOpeningChangingAndCancellingDraftDoesNotCreatePolicy() throws {
        let container = try makeContainer()
        var draft = WorkPolicyDraft()
        draft.fixedRequiredDays = 7
        draft.country = .newZealand
        draft.jurisdictionId = "NZ-AUCKLAND"

        XCTAssertEqual(draft.fixedRequiredDays, 7)
        XCTAssertTrue(try storedRules(in: container).isEmpty)
        XCTAssertFalse(container.mainContext.hasChanges)
    }

    func testFirstConfirmationCreatesOnlyChosenPolicyForAllRecordedDates() throws {
        let container = try makeContainer()
        let attendance = AttendanceDay(date: date(2026, 6, 15), finalClassification: .office, note: "Keep me")
        container.mainContext.insert(attendance)
        try container.mainContext.save()
        var draft = WorkPolicyDraft()
        draft.country = .newZealand
        draft.jurisdictionId = "NZ-AUCKLAND"
        draft.requirementType = .percentageOfEligibleDays
        draft.requiredPercentage = 0.6
        draft.selectedISOWeekdays = [4, 1, 2, 2]
        draft.preferredOfficeISOWeekdays = [2]

        let id = try WorkPolicyEditor(container: container).save(draft: draft, now: date(2026, 7, 12), calendar: calendar)
        let rules = try storedRules(in: container)
        let saved = try XCTUnwrap(rules.first)
        XCTAssertEqual(rules.count, 1)
        XCTAssertEqual(saved.id, id)
        XCTAssertNil(saved.effectiveFrom)
        XCTAssertEqual(saved.country, .newZealand)
        XCTAssertEqual(saved.jurisdictionId, "NZ-AUCKLAND")
        XCTAssertEqual(saved.requiredPercentage, 0.6)
        XCTAssertNil(saved.fixedRequiredDays)
        XCTAssertEqual(saved.selectedISOWeekdays, [1, 2, 4])
        XCTAssertEqual(saved.preferredOfficeISOWeekdays, [2])
        XCTAssertEqual(resolver.rule(for: date(2026, 6, 15), from: rules)?.id, id)
        XCTAssertEqual(try ModelContext(container).fetch(FetchDescriptor<AttendanceDay>()).first?.note, "Keep me")
    }

    func testExistingLegacyPolicyIsAcceptedWithoutAConfirmationMigrationOrExtraVersion() throws {
        let container = try makeContainer()
        let legacy = ComplianceRule(name: "Ben's existing policy", fixedRequiredDays: 8, createdAt: date(2026, 6, 1))
        container.mainContext.insert(legacy)
        try container.mainContext.save()
        let draft = WorkPolicyDraft(rule: legacy)

        let id = try WorkPolicyEditor(container: container).save(draft: draft, now: date(2026, 7, 12), calendar: calendar)

        let stored = try storedRules(in: container)
        XCTAssertEqual(id, legacy.id)
        XCTAssertEqual(stored.count, 1)
        XCTAssertNil(stored.first?.effectiveFrom)
        XCTAssertEqual(stored.first?.createdAt, date(2026, 6, 1))
        XCTAssertEqual(stored.first?.name, "Ben's existing policy")
    }

    func testEditingLegacyPolicyPreservesHistoryAndBeginsOnCurrentMonthBoundary() throws {
        let container = try makeContainer()
        let legacy = ComplianceRule(fixedRequiredDays: 8)
        container.mainContext.insert(legacy)
        try container.mainContext.save()
        var draft = WorkPolicyDraft(rule: legacy)
        draft.fixedRequiredDays = 12
        draft.minimumOfficeMinutes = 240

        try WorkPolicyEditor(container: container).save(draft: draft, now: date(2026, 7, 12), calendar: calendar)

        let stored = try storedRules(in: container)
        XCTAssertEqual(stored.count, 2)
        let before = try XCTUnwrap(resolver.rule(for: date(2026, 7, 1).addingTimeInterval(-1), from: stored))
        let after = try XCTUnwrap(resolver.rule(for: date(2026, 7, 1), from: stored))
        XCTAssertEqual(before.id, legacy.id)
        XCTAssertEqual(before.fixedRequiredDays, 8)
        XCTAssertEqual(before.minimumOfficeMinutes, 180)
        XCTAssertEqual(after.fixedRequiredDays, 12)
        XCTAssertEqual(after.minimumOfficeMinutes, 240)
        XCTAssertEqual(after.effectiveFrom, date(2026, 7, 1))
    }

    func testRepeatedChangesInOneMonthUpdateOneVersionAndNextMonthCreatesAnother() throws {
        let container = try makeContainer()
        let editor = WorkPolicyEditor(container: container)
        var draft = WorkPolicyDraft()
        let original = try editor.save(draft: draft, now: date(2026, 6, 15), calendar: calendar)
        draft.fixedRequiredDays = 8
        let july = try editor.save(draft: draft, now: date(2026, 7, 2), calendar: calendar)
        draft.fixedRequiredDays = 6
        let julyAgain = try editor.save(draft: draft, now: date(2026, 7, 25), calendar: calendar)
        draft.fixedRequiredDays = 4
        let august = try editor.save(draft: draft, now: date(2026, 8, 1), calendar: calendar)

        let stored = try storedRules(in: container)
        XCTAssertEqual(stored.count, 3)
        XCTAssertNotEqual(original, july)
        XCTAssertEqual(julyAgain, july)
        XCTAssertNotEqual(august, july)
        XCTAssertEqual(resolver.rule(for: date(2026, 6, 30), from: stored)?.fixedRequiredDays, 10)
        XCTAssertEqual(resolver.rule(for: date(2026, 7, 31), from: stored)?.fixedRequiredDays, 6)
        XCTAssertEqual(resolver.rule(for: date(2026, 8, 1), from: stored)?.fixedRequiredDays, 4)
    }

    func testFailedFirstSaveLeavesNoPolicyAndRetainedDraftCanBeRetried() throws {
        let container = try makeContainer()
        var draft = WorkPolicyDraft()
        draft.fixedRequiredDays = 7
        let failingEditor = WorkPolicyEditor(container: container, save: { _ in throw SaveFailure.unavailable })

        XCTAssertThrowsError(try failingEditor.save(draft: draft, now: date(2026, 7, 12), calendar: calendar))
        XCTAssertTrue(try storedRules(in: container).isEmpty)
        XCTAssertEqual(draft.fixedRequiredDays, 7)

        try WorkPolicyEditor(container: container).save(draft: draft, now: date(2026, 7, 12), calendar: calendar)
        XCTAssertEqual(try storedRules(in: container).first?.fixedRequiredDays, 7)
    }

    func testFailedUpdateDoesNotRollbackUnrelatedUnsavedAttendanceAndRetryUsesSameVersion() throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.autosaveEnabled = false
        let rule = ComplianceRule(fixedRequiredDays: 8, effectiveFrom: date(2026, 7, 1))
        let attendance = AttendanceDay(date: date(2026, 7, 10), finalClassification: .home, note: "Saved note")
        context.insert(rule)
        context.insert(attendance)
        try context.save()
        attendance.note = "Unrelated unsaved edit"
        var draft = WorkPolicyDraft(rule: rule)
        draft.fixedRequiredDays = 12
        let failingEditor = WorkPolicyEditor(container: container, save: { _ in throw SaveFailure.unavailable })

        XCTAssertThrowsError(try failingEditor.save(draft: draft, now: date(2026, 7, 12), calendar: calendar))

        XCTAssertEqual(try storedRules(in: container).first?.fixedRequiredDays, 8)
        XCTAssertEqual(attendance.note, "Unrelated unsaved edit")
        XCTAssertTrue(context.hasChanges)
        XCTAssertEqual(try ModelContext(container).fetch(FetchDescriptor<AttendanceDay>()).first?.note, "Saved note")

        let savedId = try WorkPolicyEditor(container: container).save(draft: draft, now: date(2026, 7, 12), calendar: calendar)
        XCTAssertEqual(savedId, rule.id)
        XCTAssertEqual(try storedRules(in: container).count, 1)
        XCTAssertEqual(try storedRules(in: container).first?.fixedRequiredDays, 12)
        XCTAssertEqual(attendance.note, "Unrelated unsaved edit")
        XCTAssertEqual(try ModelContext(container).fetch(FetchDescriptor<AttendanceDay>()).first?.note, "Saved note")
    }

    func testSavedChangesAreVisibleToExistingMainContextFetch() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let rule = ComplianceRule(fixedRequiredDays: 8, effectiveFrom: date(2026, 7, 1))
        context.insert(rule)
        try context.save()
        var draft = WorkPolicyDraft(rule: rule)
        draft.fixedRequiredDays = 12

        try WorkPolicyEditor(container: container).save(draft: draft, now: date(2026, 7, 12), calendar: calendar)

        let fetched = try XCTUnwrap(context.fetch(FetchDescriptor<ComplianceRule>()).first)
        XCTAssertEqual(fetched.fixedRequiredDays, 12)
    }

    func testInvalidTargetWorkdaysRegionAndMinimumTimeDoNotCreatePolicy() throws {
        let container = try makeContainer()
        let editor = WorkPolicyEditor(container: container)
        var candidates: [WorkPolicyDraft] = []
        var draft = WorkPolicyDraft()
        draft.fixedRequiredDays = -1
        candidates.append(draft)
        draft = WorkPolicyDraft()
        draft.requirementType = .percentageOfEligibleDays
        for value in [-0.1, 1.01, Double.nan, Double.infinity] {
            draft.requiredPercentage = value
            candidates.append(draft)
        }
        draft = WorkPolicyDraft()
        draft.selectedISOWeekdays = []
        candidates.append(draft)
        draft.selectedISOWeekdays = [0, 8]
        candidates.append(draft)
        draft = WorkPolicyDraft()
        draft.preferredOfficeISOWeekdays = [7]
        candidates.append(draft)
        draft = WorkPolicyDraft()
        draft.country = .newZealand
        candidates.append(draft)
        draft = WorkPolicyDraft()
        draft.minimumOfficeMinutes = -1
        candidates.append(draft)

        for candidate in candidates {
            XCTAssertNotNil(candidate.validationMessage)
            XCTAssertThrowsError(try editor.save(draft: candidate, now: date(2026, 7, 12), calendar: calendar))
        }
        XCTAssertTrue(try storedRules(in: container).isEmpty)
    }

    func testExplicitZeroFixedAndPercentageTargetsCanBeSaved() throws {
        let container = try makeContainer()
        let editor = WorkPolicyEditor(container: container)
        var draft = WorkPolicyDraft()
        draft.fixedRequiredDays = 0
        try editor.save(draft: draft, now: date(2026, 7, 12), calendar: calendar)
        XCTAssertEqual(try storedRules(in: container).first?.fixedRequiredDays, 0)

        draft.requirementType = .percentageOfEligibleDays
        draft.requiredPercentage = 0
        try editor.save(draft: draft, now: date(2026, 8, 1), calendar: calendar)
        let stored = try storedRules(in: container)
        XCTAssertEqual(resolver.currentRule(from: stored, now: date(2026, 8, 1))?.requiredPercentage, 0)
        XCTAssertNil(resolver.currentRule(from: stored, now: date(2026, 8, 1))?.fixedRequiredDays)
    }

    func testLocalMonthBoundaryUsesPolicyCalendarAcrossUTCDate() throws {
        let container = try makeContainer()
        let editor = WorkPolicyEditor(container: container)
        var melbourne = calendar
        melbourne.timeZone = TimeZone(identifier: "Australia/Melbourne")!
        var draft = WorkPolicyDraft()
        try editor.save(draft: draft, now: date(2026, 6, 15), calendar: melbourne)
        draft.fixedRequiredDays = 8
        // July has started locally while UTC is still June.
        let localJulyStart = try XCTUnwrap(melbourne.date(from: DateComponents(year: 2026, month: 7, day: 1)))
        try editor.save(draft: draft, now: localJulyStart.addingTimeInterval(60), calendar: melbourne)

        let stored = try storedRules(in: container)
        XCTAssertEqual(resolver.rule(for: localJulyStart.addingTimeInterval(-1), from: stored)?.fixedRequiredDays, 10)
        XCTAssertEqual(resolver.rule(for: localJulyStart, from: stored)?.fixedRequiredDays, 8)
        XCTAssertEqual(resolver.rule(for: localJulyStart, from: stored)?.effectiveFrom, localJulyStart)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([ComplianceRule.self, AttendanceDay.self])
        return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
    }

    private func storedRules(in container: ModelContainer) throws -> [ComplianceRule] {
        try ModelContext(container).fetch(FetchDescriptor<ComplianceRule>())
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}

final class OfficePlanSuggestionServiceTests: XCTestCase {
    private let service = OfficePlanSuggestionService()
    private let calendar = Calendar.workTrackCalendar

    func testPreferredWeekdaysAreSuggestedBeforeEarlierNonPreferredDays() {
        let monday = date(2026, 7, 6)
        let tuesday = date(2026, 7, 7)
        let wednesday = date(2026, 7, 8)
        let thursday = date(2026, 7, 9)

        let result = service.suggestedDates(
            from: [monday, tuesday, wednesday, thursday],
            excluding: [],
            count: 3,
            preferredISOWeekdays: [2, 4],
            calendar: calendar
        )

        XCTAssertEqual(result, [tuesday, thursday, monday])
    }

    func testSuggestionExcludesExistingPlansAndFallsBackToChronologicalOrder() {
        let monday = date(2026, 7, 6)
        let tuesday = date(2026, 7, 7)
        let wednesday = date(2026, 7, 8)

        let result = service.suggestedDates(
            from: [wednesday, monday, tuesday],
            excluding: [monday],
            count: 3,
            preferredISOWeekdays: [],
            calendar: calendar
        )

        XCTAssertEqual(result, [tuesday, wednesday])
    }

    func testBalancedSuggestionsSpreadAcrossWeeksBeforeAddingAnotherDay() {
        let firstMonday = date(2026, 8, 3)
        let firstWednesday = date(2026, 8, 5)
        let secondMonday = date(2026, 8, 10)
        let secondWednesday = date(2026, 8, 12)
        let thirdMonday = date(2026, 8, 17)
        let thirdWednesday = date(2026, 8, 19)

        let result = service.balancedSuggestedDates(
            from: [
                firstMonday,
                firstWednesday,
                secondMonday,
                secondWednesday,
                thirdMonday,
                thirdWednesday
            ],
            excluding: [],
            count: 3,
            preferredISOWeekdays: [3],
            calendar: calendar
        )

        XCTAssertEqual(result, [firstWednesday, secondWednesday, thirdWednesday])
    }

    func testBalancedSuggestionsAccountForExistingPlansInEachWeek() {
        let firstMonday = date(2026, 8, 3)
        let firstWednesday = date(2026, 8, 5)
        let secondWednesday = date(2026, 8, 12)
        let thirdWednesday = date(2026, 8, 19)

        let result = service.balancedSuggestedDates(
            from: [firstMonday, firstWednesday, secondWednesday, thirdWednesday],
            excluding: [firstMonday],
            count: 2,
            preferredISOWeekdays: [3],
            calendar: calendar
        )

        XCTAssertEqual(result, [secondWednesday, thirdWednesday])
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}

final class OfficePlanConfidenceCalculatorTests: XCTestCase {
    private let calculator = OfficePlanConfidenceCalculator()
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    func testSevenOfEightWithOneFuturePlanCoversTarget() throws {
        let confidence = calculator.evaluate(
            input(
                requiredOfficeDays: 8,
                completedDates: [
                    date("2026-07-01"),
                    date("2026-07-02"),
                    date("2026-07-03"),
                    date("2026-07-06"),
                    date("2026-07-07"),
                    date("2026-07-08"),
                    date("2026-07-09")
                ],
                plannedDates: [date("2026-07-30")],
                possibleRemainingOfficeDates: 2
            )
        )

        XCTAssertEqual(confidence.state, .covered)
        XCTAssertEqual(confidence.completedOfficeDays, 7)
        XCTAssertEqual(confidence.remainingOfficeDays, 1)
        XCTAssertEqual(confidence.nextPlannedDate, date("2026-07-30"))
        XCTAssertEqual(confidence.completionDate, date("2026-07-30"))
        XCTAssertEqual(confidence.confirmedProgress, 7.0 / 8.0, accuracy: 0.000_001)
    }

    func testPlanShortfallReportsAdditionalDaysNeeded() {
        let confidence = calculator.evaluate(
            input(
                requiredOfficeDays: 8,
                completedDates: (1...4).map { date("2026-07-\(String(format: "%02d", $0))") },
                plannedDates: [date("2026-07-30")],
                possibleRemainingOfficeDates: 5
            )
        )

        XCTAssertEqual(confidence.state, .shortfall(3))
        XCTAssertNil(confidence.completionDate)
    }

    func testStaleDuplicateAndCompletedPlansDoNotCountAgain() {
        let completedDate = date("2026-07-10")
        let confidence = calculator.evaluate(
            input(
                requiredOfficeDays: 3,
                completedDates: [completedDate, date("2026-07-31")],
                plannedDates: [
                    date("2026-07-20"),
                    completedDate,
                    date("2026-07-30"),
                    date("2026-07-30")
                ],
                possibleRemainingOfficeDates: 2
            )
        )

        XCTAssertEqual(confidence.state, .shortfall(1))
        XCTAssertEqual(confidence.completedOfficeDays, 1)
        XCTAssertEqual(confidence.plannedOfficeDates, [date("2026-07-30")])
    }

    func testAlreadyMetTargetUsesCrossingDateAsCompletion() {
        let completedDates = (1...4).map { date("2026-07-\(String(format: "%02d", $0))") }
        let confidence = calculator.evaluate(
            input(
                requiredOfficeDays: 3,
                completedDates: completedDates,
                plannedDates: [date("2026-07-30")],
                possibleRemainingOfficeDates: 2
            )
        )

        XCTAssertEqual(confidence.state, .targetMet)
        XCTAssertEqual(confidence.completionDate, date("2026-07-03"))
        XCTAssertEqual(confidence.nextPlannedDate, date("2026-07-30"))
        XCTAssertEqual(confidence.confirmedProgress, 1)
    }

    func testReviewDaysKeepIncompletePlanProvisional() {
        let confidence = calculator.evaluate(
            input(
                requiredOfficeDays: 2,
                completedDates: [date("2026-07-10")],
                plannedDates: [date("2026-07-30")],
                possibleRemainingOfficeDates: 2,
                reviewRequiredDays: 1
            )
        )

        XCTAssertEqual(confidence.state, .needsReview(1))
        XCTAssertNil(confidence.completionDate)
    }

    func testInsufficientRemainingEligibleDatesIsNotReachable() {
        let confidence = calculator.evaluate(
            input(
                requiredOfficeDays: 5,
                completedDates: [date("2026-07-10")],
                plannedDates: [date("2026-07-30")],
                possibleRemainingOfficeDates: 2
            )
        )

        XCTAssertEqual(confidence.state, .notReachable)
        XCTAssertNil(confidence.completionDate)
    }

    private func input(
        requiredOfficeDays: Int,
        completedDates: [Date],
        plannedDates: [Date],
        possibleRemainingOfficeDates: Int,
        reviewRequiredDays: Int = 0
    ) -> OfficePlanConfidenceCalculator.Input {
        OfficePlanConfidenceCalculator.Input(
            requiredOfficeDays: requiredOfficeDays,
            completedOfficeDates: Set(completedDates),
            plannedOfficeDates: plannedDates,
            possibleRemainingOfficeDates: possibleRemainingOfficeDates,
            reviewRequiredDays: reviewRequiredDays,
            evaluationDate: date("2026-07-29"),
            calendar: calendar
        )
    }

    private func date(_ isoDate: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"

        guard let date = formatter.date(from: isoDate) else {
            XCTFail("Invalid test date: \(isoDate)")
            return Date(timeIntervalSince1970: 0)
        }
        return date
    }
}
