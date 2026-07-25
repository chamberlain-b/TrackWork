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
            selectedISOWeekdays: [1, 2, 3, 4]
        )
        let effectiveFrom = date(2026, 7, 1)

        let copy = resolver.copy(original, effectiveFrom: effectiveFrom, now: date(2026, 7, 12))

        XCTAssertEqual(copy.country, .newZealand)
        XCTAssertEqual(copy.jurisdictionId, "NZ-AUCKLAND")
        XCTAssertEqual(copy.requirementType, .percentageOfEligibleDays)
        XCTAssertEqual(copy.requiredPercentage, 0.6)
        XCTAssertEqual(copy.minimumOfficeMinutes, 240)
        XCTAssertEqual(copy.selectedISOWeekdays, [1, 2, 3, 4])
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
