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
