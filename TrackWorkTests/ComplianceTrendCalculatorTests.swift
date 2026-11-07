import XCTest
@testable import TrackWork

final class ComplianceTrendCalculatorTests: XCTestCase {
    private var calendar: Calendar!
    private var calculator: ComplianceTrendCalculator!
    private var evaluator: CompliancePeriodEvaluator!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
        calculator = ComplianceTrendCalculator()
        evaluator = CompliancePeriodEvaluator()
    }

    override func tearDown() {
        calendar = nil
        calculator = nil
        evaluator = nil
        super.tearDown()
    }

    func testMonthlyQuarterlyAndYearlyPointsUseSamePeriodEvaluation() throws {
        let referenceDate = date("2026-07-15")
        let rule = ComplianceRule(
            requirementType: .percentageOfEligibleDays,
            fixedRequiredDays: nil,
            requiredPercentage: 0.5,
            selectedISOWeekdays: [1, 2, 3, 4, 5]
        )
        let attendanceDays = [attendance("2026-07-01")]
        let leaveRecords = [leave("2026-07-06")]
        let customExcludedDays = [CustomExcludedDay(date: date("2026-07-07"))]

        for granularity in ComplianceTrendGranularity.allCases {
            let point = try XCTUnwrap(
                calculator.points(
                    granularity: granularity,
                    endingAt: referenceDate,
                    bucketCount: 1,
                    calendar: calendar,
                    rule: rule,
                    attendanceDays: attendanceDays,
                    leaveRecords: leaveRecords,
                    publicHolidays: [],
                    customExcludedDays: customExcludedDays
                ).first
            )
            let directSummary = evaluator.evaluate(
                CompliancePeriodEvaluator.Input(
                    range: point.range,
                    calendar: calendar,
                    rule: rule,
                    attendanceDays: attendanceDays,
                    leaveRecords: leaveRecords,
                    publicHolidays: [],
                    customExcludedDays: customExcludedDays,
                    evaluationDate: referenceDate
                )
            )

            XCTAssertEqual(point.completedOfficeDays, directSummary.completedOfficeDays, granularity.rawValue)
            XCTAssertEqual(point.requiredOfficeDays, directSummary.requiredOfficeDays, granularity.rawValue)
            XCTAssertTrue(point.hasRecordedData, granularity.rawValue)
        }
    }

    func testTrendBucketBoundariesAreInclusiveAndCalendarAligned() throws {
        let referenceDate = date("2026-07-15")
        let rule = ComplianceRule(requirementType: .fixedMonthlyDays, fixedRequiredDays: 10)
        let expectations = [
            TrendRangeExpectation(.monthly, start: "2026-07-01", end: "2026-07-31"),
            TrendRangeExpectation(.quarterly, start: "2026-07-01", end: "2026-09-30"),
            TrendRangeExpectation(.yearly, start: "2026-01-01", end: "2026-12-31")
        ]

        for expectation in expectations {
            let point = try XCTUnwrap(
                calculator.points(
                    granularity: expectation.granularity,
                    endingAt: referenceDate,
                    bucketCount: 1,
                    calendar: calendar,
                    rule: rule,
                    attendanceDays: [],
                    leaveRecords: [],
                    publicHolidays: [],
                    customExcludedDays: []
                ).first
            )

            XCTAssertEqual(point.range.start, date(expectation.start), expectation.granularity.rawValue)
            XCTAssertEqual(point.range.end, date(expectation.end), expectation.granularity.rawValue)
        }
    }

    func testMonthlyBucketsUseRuleEffectiveAtEachBucketEnd() {
        let legacyRule = ComplianceRule(
            name: "Legacy target",
            requirementType: .fixedMonthlyDays,
            fixedRequiredDays: 4
        )
        let julyRule = ComplianceRule(
            name: "July target",
            requirementType: .fixedMonthlyDays,
            fixedRequiredDays: 9,
            effectiveFrom: date("2026-07-01")
        )

        let points = calculator.points(
            granularity: .monthly,
            endingAt: date("2026-07-15"),
            bucketCount: 2,
            calendar: calendar,
            rules: [julyRule, legacyRule],
            attendanceDays: [],
            leaveRecords: [],
            publicHolidays: [],
            customExcludedDays: []
        )

        XCTAssertEqual(points.map(\.range.start), [date("2026-06-01"), date("2026-07-01")])
        XCTAssertEqual(points.map(\.requiredOfficeDays), [4, 9])
    }

    private func attendance(_ isoDate: String) -> AttendanceDay {
        AttendanceDay(
            date: date(isoDate),
            detectedClassification: .office,
            finalClassification: .office,
            complianceTreatment: .countsAsOffice,
            officeMinutes: 180
        )
    }

    private func leave(_ isoDate: String) -> LeaveRecord {
        LeaveRecord(date: date(isoDate), leaveType: .annualLeave)
    }

    private func date(_ isoDate: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        guard let date = formatter.date(from: isoDate) else {
            XCTFail("Invalid test fixture date: \(isoDate)")
            return Date(timeIntervalSince1970: 0)
        }

        return date
    }
}

private struct TrendRangeExpectation {
    let granularity: ComplianceTrendGranularity
    let start: String
    let end: String

    init(_ granularity: ComplianceTrendGranularity, start: String, end: String) {
        self.granularity = granularity
        self.start = start
        self.end = end
    }
}

// MARK: - Read-only attendance analytics presentation

final class AttendancePeriodPresentationTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }
    private let builder = AttendancePeriodPresentationBuilder()

    func testMixUsesRecordedEligibleDaysAndOfficeShareKeepsItsDenominator() throws {
        let result = try builder.make(input(attendance: [
            day("2026-07-01", .office), day("2026-07-02", .mixed, minutes: 179),
            day("2026-07-03", .mixed, minutes: 180), day("2026-07-06", .unknown)
        ], reference: "2026-07-06"))
        XCTAssertEqual(result.mix, AttendanceMix(officeDays: 2, homeDays: 1))
        XCTAssertEqual(try XCTUnwrap(result.mix.officeShare), 2.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(result.summary.officeShareToDate, 0.5)
        XCTAssertEqual(result.days.first { $0.date == date("2026-07-02") }?.classification, .mixed)
    }

    func testExclusionsAndLeaveHolidayOverlapNeverBecomeHome() throws {
        let result = try builder.make(input(
            attendance: [day("2026-07-01", .office), day("2026-07-02", .office),
                         day("2026-07-03", .office), day("2026-07-04", .office), day("2026-07-06", .home)],
            leave: [LeaveRecord(date: date("2026-07-01"), leaveType: .annualLeave),
                    LeaveRecord(date: date("2026-07-02"), leaveType: .sickLeave)],
            holidays: [holiday("2026-07-01")],
            exclusions: [CustomExcludedDay(date: date("2026-07-03"))]
        ))
        XCTAssertEqual(result.mix, AttendanceMix(officeDays: 0, homeDays: 1))
        XCTAssertEqual(result.days.first?.classification, .publicHoliday)
        XCTAssertEqual(result.days[1].classification, .sickLeave)
        XCTAssertTrue(result.days[2].isExcluded)
    }

    func testRecordedHolidayAndLeaveKeepCalendarPrecedenceWithoutSourceRecords() throws {
        let result = try builder.make(input(
            attendance: [day("2026-07-01", .publicHoliday), day("2026-07-02", .annualLeave)],
            exclusions: [CustomExcludedDay(date: date("2026-07-01")), CustomExcludedDay(date: date("2026-07-02"))]
        ))
        XCTAssertEqual(result.days[0].classification, .publicHoliday)
        XCTAssertEqual(result.days[1].classification, .annualLeave)
        XCTAssertFalse(result.days[0].isExcluded)
        XCTAssertFalse(result.days[1].isExcluded)
        XCTAssertEqual(result.mix.totalDays, 0)
    }

    func testFutureAndUnrecordedDaysDoNotContributeToMix() throws {
        let result = try builder.make(input(attendance: [day("2026-07-30", .office)]))
        XCTAssertEqual(result.mix.totalDays, 0)
        XCTAssertNil(result.mix.officeShare)
        XCTAssertNil(result.mix.homeShare)
        XCTAssertEqual(result.days.first?.label, "Unrecorded")
        XCTAssertTrue(result.days.last!.isUpcoming)
    }

    func testStableDateIdentityAndOverrideProvenance() throws {
        let record = day("2026-07-01", .home)
        record.manualClassificationRaw = AttendanceClassification.home.rawValue
        let first = try builder.make(input(attendance: [record]))
        let second = try builder.make(input(attendance: [record]))
        XCTAssertEqual(first.days.map(\.id), second.days.map(\.id))
        XCTAssertTrue(first.days[0].isOverride)
        XCTAssertEqual(Set(first.days.map(\.id)).count, 31)
    }

    func testDuplicateRowsUseLatestReportStatusWithoutChangingCalculatorSemantics() throws {
        let older = day("2026-07-01", .office)
        older.updatedAt = date("2026-07-01")
        let newer = day("2026-07-01", .home)
        newer.updatedAt = date("2026-07-02")
        let result = try builder.make(input(attendance: [older, newer]))
        XCTAssertEqual(result.mix, AttendanceMix(officeDays: 0, homeDays: 1))
        XCTAssertEqual(result.days[0].classification, .home)
        // Existing calculator counts any confirmed office entry on the date; no migration here.
        XCTAssertEqual(result.summary.completedOfficeDays, 1)
    }

    func testHistoricalTrendUsesBucketEndRuleAndRetainsExistingTargets() throws {
        let old = ComplianceRule(minimumOfficeMinutes: 180, effectiveFrom: date("2026-01-01"))
        let new = ComplianceRule(minimumOfficeMinutes: 240, effectiveFrom: date("2026-07-01"))
        let records = [day("2026-06-01", .mixed, minutes: 200), day("2026-07-01", .mixed, minutes: 200)]
        let source = input(attendance: records, rules: [old, new])
        let monthly = try builder.trends(source, granularity: .monthly)
        XCTAssertEqual(monthly.suffix(2).first?.mix.officeDays, 1)
        XCTAssertEqual(monthly.last?.mix.homeDays, 1)
        for granularity in ComplianceTrendGranularity.allCases {
            let presented = try builder.trends(source, granularity: granularity)
            let existing = ComplianceTrendCalculator().points(
                granularity: granularity, endingAt: source.range.end, calendar: calendar, rules: [old, new],
                attendanceDays: records, leaveRecords: [], publicHolidays: [], customExcludedDays: []
            )
            XCTAssertEqual(presented.map(\.point), existing)
            XCTAssertEqual(presented.count, 6)
        }
    }

    func testHolidayJurisdictionAndMissingCoverageRemainExplicit() throws {
        let source = input(attendance: [day("2026-07-01", .office)],
                           holidays: [holiday("2026-07-01", jurisdiction: "AU-NSW")])
        XCTAssertEqual(try builder.make(source).mix.officeDays, 1)
        let missingRange = ComplianceDateRange(start: date("2025-01-01"), end: date("2025-01-31"), calendar: calendar)
        XCTAssertNotNil(try builder.make(source.replacingRange(missingRange)).coverageWarning)
    }

    func testCustomRangeNormalizesReversedInclusiveBoundaries() throws {
        let range = ComplianceDateRange(start: date("2026-07-03"), end: date("2026-07-01"), calendar: calendar)
        let source = input(attendance: [day("2026-07-01", .office), day("2026-07-03", .home)])
        let result = try builder.make(source.replacingRange(range))
        XCTAssertEqual(result.days.count, 3)
        XCTAssertEqual(result.mix.totalDays, 2)
        XCTAssertEqual(result.days.first?.date, date("2026-07-01"))
        XCTAssertEqual(result.days.last?.date, date("2026-07-03"))
    }

    func testSharedSelectionUsesExistingPresetsAndCurrentMonthDefault() {
        let selection = ReportingPeriodSelection(referenceDate: date("2026-07-29"))
        XCTAssertEqual(selection.preset, .currentMonth)
        selection.preset = .previousQuarter
        let range = selection.range(calendar: calendar, referenceDate: date("2026-07-29"))
        XCTAssertEqual(range.start, date("2026-04-01"))
        XCTAssertEqual(range.end, date("2026-06-30"))
    }

    private func input(attendance: [AttendanceDay] = [], leave: [LeaveRecord] = [],
                       holidays: [PublicHoliday] = [], exclusions: [CustomExcludedDay] = [],
                       reference: String = "2026-07-29", rules: [ComplianceRule]? = nil) -> AttendancePeriodPresentationBuilder.Input {
        .init(range: ComplianceDateRange(start: date("2026-07-01"), end: date("2026-07-31"), calendar: calendar),
              calendar: calendar, referenceDate: date(reference), rules: rules ?? [ComplianceRule()],
              attendanceDays: attendance, leaveRecords: leave, publicHolidays: holidays, customExcludedDays: exclusions)
    }

    private func day(_ value: String, _ status: AttendanceClassification, minutes: Int = 0) -> AttendanceDay {
        AttendanceDay(date: date(value), finalClassification: status, officeMinutes: minutes)
    }

    private func holiday(_ value: String, jurisdiction: String = "AU-VIC") -> PublicHoliday {
        PublicHoliday(date: date(value), name: "Fixture holiday", country: .australia,
                      jurisdictionId: jurisdiction, isRegional: false, sourceName: "Tests")
    }

    private func date(_ value: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)!
    }
}


final class InsightsTargetPresentationTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testCompletionUsesRequiredOfficeDaysAndDoesNotClaimOnTrack() throws {
        let result = presentation(summary: summary(completed: 16, required: 20))

        XCTAssertEqual(try XCTUnwrap(result.completionFraction), 0.8, accuracy: 0.0001)
        XCTAssertEqual(result.progressFraction, 0.8, accuracy: 0.0001)
        XCTAssertEqual(result.status, .remaining)
        XCTAssertEqual(result.statusText, "4 office days still needed")
        XCTAssertEqual(result.officeDaysNeeded, 4)
    }

    func testAboveTargetPreservesActualCompletionAndCapsOnlyBar() throws {
        let result = presentation(summary: summary(completed: 12, required: 8))

        XCTAssertEqual(try XCTUnwrap(result.completionFraction), 1.5, accuracy: 0.0001)
        XCTAssertEqual(result.progressFraction, 1)
        XCTAssertEqual(result.officeDaysNeeded, 0)
        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(result.statusText, "Target reached")
    }

    func testUnconfiguredTargetIsDistinctFromZeroRequiredDays() {
        let unconfigured = presentation(summary: summary(completed: 0, required: 0), configured: false)
        let zeroRequired = presentation(summary: summary(completed: 0, required: 0))

        XCTAssertNil(unconfigured.completionFraction)
        XCTAssertNil(zeroRequired.completionFraction)
        XCTAssertEqual(unconfigured.progressFraction, 0)
        XCTAssertEqual(zeroRequired.progressFraction, 0)
        XCTAssertEqual(unconfigured.status, .notConfigured)
        XCTAssertEqual(zeroRequired.status, .noRequiredDays)
        XCTAssertEqual(unconfigured.completionText, "No target configured")
        XCTAssertEqual(zeroRequired.completionText, "No office days required")
    }

    func testConfigurationFlagPreventsFallbackTargetBeingPresentedAsConfigured() {
        let result = presentation(summary: summary(completed: 2, required: 10), configured: false)

        XCTAssertNil(result.completionFraction)
        XCTAssertEqual(result.progressFraction, 0)
        XCTAssertEqual(result.status, .notConfigured)
    }

    func testPeriodEndUsesCalendarDayAndOnlyPastPeriodShowsShortfall() {
        let lastEvening = date("2026-07-31").addingTimeInterval(23 * 60 * 60)
        let finalDay = presentation(summary: summary(completed: 7, required: 8), referenceDate: lastEvening)
        let ended = presentation(summary: summary(completed: 7, required: 8), referenceDate: date("2026-08-01"))

        XCTAssertEqual(finalDay.status, .remaining)
        XCTAssertEqual(finalDay.statusText, "1 office day still needed")
        XCTAssertEqual(ended.status, .endedShortfall)
        XCTAssertEqual(ended.statusText, "Period ended · 1 office day short of target")
    }

    func testEndedPeriodWithCompletedTargetStillShowsReached() {
        let result = presentation(summary: summary(completed: 8, required: 8), referenceDate: date("2026-08-01"))

        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(result.officeDaysNeeded, 0)
    }

    func testNoRecordedDaysIsZeroTargetCompletionButHasNoOfficeShare() throws {
        let result = presentation(summary: summary(completed: 0, required: 8))
        let mix = AttendanceMix(officeDays: 0, homeDays: 0)

        XCTAssertEqual(try XCTUnwrap(result.completionFraction), 0)
        XCTAssertNil(mix.officeShare)
        XCTAssertEqual(result.status, .remaining)
    }

    func testTargetCompletionAndRecordedOfficeShareKeepDifferentDenominators() throws {
        let period = try AttendancePeriodPresentationBuilder().make(.init(
            range: range, calendar: calendar, referenceDate: date("2026-07-08"),
            rules: [ComplianceRule(fixedRequiredDays: 10)],
            attendanceDays: [
                AttendanceDay(date: date("2026-07-06"), finalClassification: .office),
                AttendanceDay(date: date("2026-07-07"), finalClassification: .home),
                AttendanceDay(date: date("2026-07-08"), finalClassification: .unknown),
                AttendanceDay(date: date("2026-07-09"), finalClassification: .office)
            ],
            leaveRecords: [], publicHolidays: [], customExcludedDays: []
        ))
        let target = presentation(summary: period.summary, referenceDate: date("2026-07-08"))

        XCTAssertEqual(try XCTUnwrap(target.completionFraction), 0.1, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(period.mix.officeShare), 0.5, accuracy: 0.0001)
        XCTAssertEqual(period.mix.totalDays, 2)
        XCTAssertEqual(target.officeDaysNeeded, 9)
    }

    func testLeaveImpactUsesEffectiveDaysWithoutDoubleCountingOverlaps() {
        let result = CompliancePeriodEvaluator().evaluate(.init(
            range: range, calendar: calendar,
            rule: ComplianceRule(requirementType: .percentageOfEligibleDays, fixedRequiredDays: nil, requiredPercentage: 0.5),
            attendanceDays: [],
            leaveRecords: [
                LeaveRecord(date: date("2026-07-01"), leaveType: .annualLeave), // Public holiday.
                LeaveRecord(date: date("2026-07-02"), leaveType: .annualLeave),
                LeaveRecord(date: date("2026-07-02"), leaveType: .sickLeave), // Duplicate eligible date.
                LeaveRecord(date: date("2026-07-04"), leaveType: .annualLeave) // Weekend.
            ],
            publicHolidays: [PublicHoliday(
                date: date("2026-07-01"), name: "Fixture holiday", country: .australia,
                jurisdictionId: "AU-VIC", isRegional: false, sourceName: "Tests"
            )],
            customExcludedDays: [
                CustomExcludedDay(date: date("2026-07-02")), // Already removed by leave.
                CustomExcludedDay(date: date("2026-07-03")),
                CustomExcludedDay(date: date("2026-07-04")) // Weekend.
            ],
            evaluationDate: date("2026-07-08")
        ))
        let target = presentation(summary: result)

        XCTAssertEqual(result.baseEligibleDays, 22)
        XCTAssertEqual(result.adjustedEligibleDays, 20)
        XCTAssertEqual(result.customExcludedDays, 1)
        XCTAssertEqual(target.eligibleLeaveDays, 1)
        XCTAssertEqual(result.requiredOfficeDays, 10)
        XCTAssertEqual(result.baseEligibleDays - target.eligibleLeaveDays - result.customExcludedDays,
                       result.adjustedEligibleDays)
    }

    func testLeaveImpactNeverDisplaysNegativeDays() {
        let inconsistentSummary = ComplianceSummary(
            baseEligibleDays: 20, adjustedEligibleDays: 20, eligibleDaysToDate: 5,
            customExcludedDays: 1, requiredOfficeDays: 8, completedOfficeDays: 0, reviewRequiredDays: 0
        )

        XCTAssertEqual(presentation(summary: inconsistentSummary).eligibleLeaveDays, 0)
    }

    private var range: ComplianceDateRange {
        ComplianceDateRange(start: date("2026-07-01"), end: date("2026-07-31"), calendar: calendar)
    }

    private func presentation(
        summary: ComplianceSummary, configured: Bool = true, referenceDate: Date? = nil
    ) -> InsightsTargetPresentation {
        InsightsTargetPresentation(summary: summary, targetIsConfigured: configured, range: range,
                                   referenceDate: referenceDate ?? date("2026-07-20"), calendar: calendar)
    }

    private func summary(completed: Int, required: Int) -> ComplianceSummary {
        ComplianceSummary(baseEligibleDays: 23, adjustedEligibleDays: 23, eligibleDaysToDate: 14,
                          customExcludedDays: 0, requiredOfficeDays: required,
                          completedOfficeDays: completed, reviewRequiredDays: 0)
    }

    private func date(_ value: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)!
    }
}
