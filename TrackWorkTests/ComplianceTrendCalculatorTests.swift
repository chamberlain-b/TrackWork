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
        let expectations: [(ComplianceTrendGranularity, String, String)] = [
            (.monthly, "2026-07-01", "2026-07-31"),
            (.quarterly, "2026-07-01", "2026-09-30"),
            (.yearly, "2026-01-01", "2026-12-31")
        ]

        for (granularity, expectedStart, expectedEnd) in expectations {
            let point = try XCTUnwrap(
                calculator.points(
                    granularity: granularity,
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

            XCTAssertEqual(point.range.start, date(expectedStart), granularity.rawValue)
            XCTAssertEqual(point.range.end, date(expectedEnd), granularity.rawValue)
        }
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
