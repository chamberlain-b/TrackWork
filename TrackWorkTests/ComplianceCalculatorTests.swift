import XCTest
@testable import TrackWork

final class ComplianceCalculatorTests: XCTestCase {
    private var calendar: Calendar!
    private var calculator: ComplianceCalculator!

    override func setUp() {
        super.setUp()

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
        calculator = ComplianceCalculator()
    }

    override func tearDown() {
        calendar = nil
        calculator = nil

        super.tearDown()
    }

    func testPercentageRequirementProratesForAnnualAndSickLeave() throws {
        let input = input(
            leaveRecords: [
                leave("2026-07-06", type: .annualLeave),
                leave("2026-07-07", type: .annualLeave),
                leave("2026-07-08", type: .annualLeave),
                leave("2026-07-09", type: .sickLeave)
            ],
            requirement: .percentageOfEligibleDays(0.5)
        )

        let summary = try calculator.calculate(input)

        XCTAssertEqual(summary.baseEligibleDays, 23)
        XCTAssertEqual(summary.adjustedEligibleDays, 19)
        XCTAssertEqual(summary.requiredOfficeDays, 10)
    }

    func testFixedRequirementProratesForLeaveByDefault() throws {
        let input = input(
            leaveRecords: fourEligibleWeekdayLeaveRecords(),
            requirement: .fixedMonthlyDays(baseRequiredDays: 10, prorateForLeave: true)
        )

        let summary = try calculator.calculate(input)

        XCTAssertEqual(summary.baseEligibleDays, 23)
        XCTAssertEqual(summary.adjustedEligibleDays, 19)
        XCTAssertEqual(summary.requiredOfficeDays, 9)
    }

    func testFixedRequirementDoesNotProrateWhenDisabled() throws {
        let input = input(
            leaveRecords: fourEligibleWeekdayLeaveRecords(),
            requirement: .fixedMonthlyDays(baseRequiredDays: 10, prorateForLeave: false)
        )

        let summary = try calculator.calculate(input)

        XCTAssertEqual(summary.baseEligibleDays, 23)
        XCTAssertEqual(summary.adjustedEligibleDays, 19)
        XCTAssertEqual(summary.requiredOfficeDays, 10)
    }

    func testFullDayLeaveOnWeekendHasNoEligibleDayImpact() throws {
        let input = input(
            leaveRecords: [leave("2026-07-04", type: .annualLeave)],
            requirement: .percentageOfEligibleDays(0.5)
        )

        let summary = try calculator.calculate(input)

        XCTAssertEqual(summary.baseEligibleDays, 23)
        XCTAssertEqual(summary.adjustedEligibleDays, 23)
    }

    func testFullDayLeaveOnPublicHolidayHasNoEligibleDayImpactAndDoesNotDoubleReduce() throws {
        let publicHoliday = date("2026-07-08")
        let input = input(
            publicHolidays: [publicHoliday],
            leaveRecords: [leave("2026-07-08", type: .annualLeave)],
            requirement: .percentageOfEligibleDays(0.5)
        )

        let summary = try calculator.calculate(input)

        XCTAssertEqual(summary.baseEligibleDays, 22)
        XCTAssertEqual(summary.adjustedEligibleDays, 22)
    }

    func testMultipleLeaveRecordsOnSameEligibleDateAreCappedAtOneDayImpact() throws {
        let input = input(
            leaveRecords: [
                leave("2026-07-08", type: .annualLeave),
                leave("2026-07-08", type: .sickLeave)
            ],
            requirement: .percentageOfEligibleDays(0.5)
        )

        let summary = try calculator.calculate(input)

        XCTAssertEqual(summary.baseEligibleDays, 23)
        XCTAssertEqual(summary.adjustedEligibleDays, 22)
    }

    func testCompletedOfficeDaysCountOfficeAndMixedWhenOfficeThresholdIsMet() throws {
        let input = input(
            attendanceDays: [
                attendance("2026-07-01", finalClassification: .office, officeMinutes: 180),
                attendance("2026-07-02", finalClassification: .mixed, officeMinutes: 180),
                attendance("2026-07-03", finalClassification: .mixed, officeMinutes: 179),
                attendance("2026-07-06", finalClassification: .home, officeMinutes: 0)
            ],
            requirement: .percentageOfEligibleDays(0.5)
        )

        let summary = try calculator.calculate(input)

        XCTAssertEqual(summary.completedOfficeDays, 2)
    }

    func testUnknownDaysAreCountedAsRequiringReview() throws {
        let input = input(
            attendanceDays: [
                attendance("2026-07-01", finalClassification: .unknown, officeMinutes: 0),
                attendance("2026-07-02", finalClassification: .office, officeMinutes: 180),
                attendance("2026-07-03", finalClassification: .unknown, officeMinutes: 0)
            ],
            requirement: .percentageOfEligibleDays(0.5)
        )

        let summary = try calculator.calculate(input)

        XCTAssertEqual(summary.reviewRequiredDays, 2)
    }

    private func input(
        publicHolidays: Set<Date> = [],
        leaveRecords: [ComplianceCalculator.LeaveRecord] = [],
        attendanceDays: [ComplianceCalculator.AttendanceDay] = [],
        requirement: ComplianceCalculator.Requirement
    ) -> ComplianceCalculator.Input {
        ComplianceCalculator.Input(
            periodStart: date("2026-07-01"),
            periodEnd: date("2026-07-31"),
            calendar: calendar,
            selectedISOWeekdays: [1, 2, 3, 4, 5],
            publicHolidays: publicHolidays,
            leaveRecords: leaveRecords,
            attendanceDays: attendanceDays,
            requirement: requirement
        )
    }

    private func fourEligibleWeekdayLeaveRecords() -> [ComplianceCalculator.LeaveRecord] {
        [
            leave("2026-07-06", type: .annualLeave),
            leave("2026-07-07", type: .annualLeave),
            leave("2026-07-08", type: .annualLeave),
            leave("2026-07-09", type: .sickLeave)
        ]
    }

    private func leave(_ isoDate: String, type: LeaveType) -> ComplianceCalculator.LeaveRecord {
        ComplianceCalculator.LeaveRecord(
            date: date(isoDate),
            type: type,
            duration: .fullDay
        )
    }

    private func attendance(
        _ isoDate: String,
        finalClassification: AttendanceClassification,
        officeMinutes: Int
    ) -> ComplianceCalculator.AttendanceDay {
        ComplianceCalculator.AttendanceDay(
            date: date(isoDate),
            finalClassification: finalClassification,
            officeMinutes: officeMinutes
        )
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
