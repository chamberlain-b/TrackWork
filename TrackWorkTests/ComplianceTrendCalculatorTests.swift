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
