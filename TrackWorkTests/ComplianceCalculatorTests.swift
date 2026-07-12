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

    func testPercentageRequirementProratesForAnnualAndSickLeave() {
        let input = input(
            leaveRecords: [
                leave("2026-07-06", type: .annualLeave),
                leave("2026-07-07", type: .annualLeave),
                leave("2026-07-08", type: .annualLeave),
                leave("2026-07-09", type: .sickLeave)
            ],
            requirement: .percentageOfEligibleDays(0.5)
        )

        let summary = calculator.calculate(input)

        XCTAssertEqual(summary.baseEligibleDays, 23)
        XCTAssertEqual(summary.adjustedEligibleDays, 19)
        XCTAssertEqual(summary.requiredOfficeDays, 10)
    }

    func testFixedRequirementProratesForLeaveByDefault() {
        let input = input(
            leaveRecords: fourEligibleWeekdayLeaveRecords(),
            requirement: .fixedMonthlyDays(baseRequiredDays: 10, prorateForLeave: true)
        )

        let summary = calculator.calculate(input)

        XCTAssertEqual(summary.baseEligibleDays, 23)
        XCTAssertEqual(summary.adjustedEligibleDays, 19)
        XCTAssertEqual(summary.requiredOfficeDays, 9)
    }

    func testFixedRequirementDoesNotProrateWhenDisabled() {
        let input = input(
            leaveRecords: fourEligibleWeekdayLeaveRecords(),
            requirement: .fixedMonthlyDays(baseRequiredDays: 10, prorateForLeave: false)
        )

        let summary = calculator.calculate(input)

        XCTAssertEqual(summary.baseEligibleDays, 23)
        XCTAssertEqual(summary.adjustedEligibleDays, 19)
        XCTAssertEqual(summary.requiredOfficeDays, 10)
    }

    func testFullDayLeaveOnWeekendHasNoEligibleDayImpact() {
        let input = input(
            leaveRecords: [leave("2026-07-04", type: .annualLeave)],
            requirement: .percentageOfEligibleDays(0.5)
        )

        let summary = calculator.calculate(input)

        XCTAssertEqual(summary.baseEligibleDays, 23)
        XCTAssertEqual(summary.adjustedEligibleDays, 23)
    }

    func testFullDayLeaveOnPublicHolidayHasNoEligibleDayImpactAndDoesNotDoubleReduce() {
        let publicHoliday = date("2026-07-08")
        let input = input(
            publicHolidays: [publicHoliday],
            leaveRecords: [leave("2026-07-08", type: .annualLeave)],
            requirement: .percentageOfEligibleDays(0.5)
        )

        let summary = calculator.calculate(input)

        XCTAssertEqual(summary.baseEligibleDays, 22)
        XCTAssertEqual(summary.adjustedEligibleDays, 22)
    }

    func testMultipleLeaveRecordsOnSameEligibleDateAreCappedAtOneDayImpact() {
        let input = input(
            leaveRecords: [
                leave("2026-07-08", type: .annualLeave),
                leave("2026-07-08", type: .sickLeave)
            ],
            requirement: .percentageOfEligibleDays(0.5)
        )

        let summary = calculator.calculate(input)

        XCTAssertEqual(summary.baseEligibleDays, 23)
        XCTAssertEqual(summary.adjustedEligibleDays, 22)
    }

    func testCustomExcludedWorkdayReducesEligibilityAndPercentageTarget() {
        let input = input(
            customExcludedDates: [date("2026-07-08")],
            requirement: .percentageOfEligibleDays(0.5)
        )

        let summary = calculator.calculate(input)

        XCTAssertEqual(summary.baseEligibleDays, 23)
        XCTAssertEqual(summary.adjustedEligibleDays, 22)
        XCTAssertEqual(summary.customExcludedDays, 1)
        XCTAssertEqual(summary.requiredOfficeDays, 11)
    }

    func testCustomExclusionDoesNotDoubleReduceLeaveOrHolidayAndIgnoresWeekend() {
        let input = input(
            publicHolidays: [date("2026-07-08")],
            leaveRecords: [leave("2026-07-09", type: .annualLeave)],
            customExcludedDates: [
                date("2026-07-04"),
                date("2026-07-08"),
                date("2026-07-09"),
                date("2026-07-10")
            ],
            requirement: .percentageOfEligibleDays(0.5)
        )

        let summary = calculator.calculate(input)

        XCTAssertEqual(summary.baseEligibleDays, 22)
        XCTAssertEqual(summary.adjustedEligibleDays, 20)
        XCTAssertEqual(summary.customExcludedDays, 1)
    }

    func testCustomExcludedOfficeDayDoesNotCountAsCompletedOrRequireReview() {
        let input = input(
            customExcludedDates: [date("2026-07-01")],
            attendanceDays: [
                attendance("2026-07-01", finalClassification: .office, officeMinutes: 180)
            ],
            requirement: .percentageOfEligibleDays(0.5),
            evaluationDate: date("2026-07-02")
        )

        let summary = calculator.calculate(input)

        XCTAssertEqual(summary.completedOfficeDays, 0)
        XCTAssertEqual(summary.reviewRequiredDays, 0)
    }

    func testCompletedOfficeDaysCountOfficeAndMixedWhenOfficeThresholdIsMet() {
        let input = input(
            attendanceDays: [
                attendance("2026-07-01", finalClassification: .office, officeMinutes: 180),
                attendance("2026-07-02", finalClassification: .mixed, officeMinutes: 180),
                attendance("2026-07-03", finalClassification: .mixed, officeMinutes: 179),
                attendance("2026-07-06", finalClassification: .home, officeMinutes: 0)
            ],
            requirement: .percentageOfEligibleDays(0.5)
        )

        let summary = calculator.calculate(input)

        XCTAssertEqual(summary.completedOfficeDays, 2)
    }

    func testCompletedMixedDaysUseConfiguredMinimumOfficeMinutes() {
        let input = input(
            attendanceDays: [
                attendance("2026-07-01", finalClassification: .mixed, officeMinutes: 239),
                attendance("2026-07-02", finalClassification: .mixed, officeMinutes: 240)
            ],
            requirement: .percentageOfEligibleDays(0.5),
            minimumOfficeMinutes: 240
        )

        let summary = calculator.calculate(input)

        XCTAssertEqual(summary.completedOfficeDays, 1)
    }

    func testCompletedOfficeDaysExcludeWeekendHolidayAndLeaveDates() {
        let input = input(
            publicHolidays: [date("2026-07-08")],
            leaveRecords: [leave("2026-07-09", type: .annualLeave)],
            attendanceDays: [
                attendance("2026-07-01", finalClassification: .office, officeMinutes: 180),
                attendance("2026-07-04", finalClassification: .office, officeMinutes: 180),
                attendance("2026-07-08", finalClassification: .office, officeMinutes: 180),
                attendance("2026-07-09", finalClassification: .office, officeMinutes: 180)
            ],
            requirement: .percentageOfEligibleDays(0.5)
        )

        let summary = calculator.calculate(input)

        XCTAssertEqual(summary.completedOfficeDays, 1)
    }

    func testEvaluationDateIncludesTodayInCompletedOfficeDaysAndExcludesFutureDays() {
        let input = input(
            attendanceDays: [
                attendance("2026-07-02", finalClassification: .office, officeMinutes: 180),
                attendance("2026-07-03", finalClassification: .mixed, officeMinutes: 180),
                attendance("2026-07-06", finalClassification: .office, officeMinutes: 180)
            ],
            requirement: .percentageOfEligibleDays(0.5),
            evaluationDate: date("2026-07-03")
        )

        let summary = calculator.calculate(input)

        XCTAssertEqual(summary.completedOfficeDays, 2)
    }

    func testOfficeShareToDateIncludesEvaluationDayAndExcludesFutureDays() throws {
        let input = input(
            attendanceDays: [
                attendance("2026-07-01", finalClassification: .office, officeMinutes: 180),
                attendance("2026-07-03", finalClassification: .mixed, officeMinutes: 180),
                attendance("2026-07-06", finalClassification: .office, officeMinutes: 180)
            ],
            requirement: .percentageOfEligibleDays(0.5),
            evaluationDate: date("2026-07-03")
        )

        let summary = calculator.calculate(input)
        let officeShareToDate = try XCTUnwrap(summary.officeShareToDate)

        XCTAssertEqual(summary.eligibleDaysToDate, 3)
        XCTAssertEqual(summary.completedOfficeDays, 2)
        XCTAssertEqual(officeShareToDate, 2.0 / 3.0, accuracy: 0.000_001)
    }

    func testOfficeShareToDateUsesEligibleDaysAfterLeaveHolidayAndCustomExclusions() throws {
        let input = input(
            publicHolidays: [date("2026-07-02")],
            leaveRecords: [leave("2026-07-06", type: .annualLeave)],
            customExcludedDates: [date("2026-07-08")],
            attendanceDays: [
                attendance("2026-07-01", finalClassification: .office, officeMinutes: 180),
                attendance("2026-07-02", finalClassification: .office, officeMinutes: 180),
                attendance("2026-07-06", finalClassification: .office, officeMinutes: 180),
                attendance("2026-07-08", finalClassification: .office, officeMinutes: 180),
                attendance("2026-07-09", finalClassification: .mixed, officeMinutes: 180),
                attendance("2026-07-13", finalClassification: .office, officeMinutes: 180)
            ],
            requirement: .percentageOfEligibleDays(0.5),
            evaluationDate: date("2026-07-10")
        )

        let summary = calculator.calculate(input)
        let officeShareToDate = try XCTUnwrap(summary.officeShareToDate)

        XCTAssertEqual(summary.eligibleDaysToDate, 5)
        XCTAssertEqual(summary.completedOfficeDays, 2)
        XCTAssertEqual(officeShareToDate, 0.4, accuracy: 0.000_001)
    }

    func testOfficeShareToDateIsNilWhenNoEligibleDaysExistThroughEvaluationDate() {
        let input = input(
            publicHolidays: [
                date("2026-07-01"),
                date("2026-07-02"),
                date("2026-07-03")
            ],
            attendanceDays: [
                attendance("2026-07-01", finalClassification: .office, officeMinutes: 180)
            ],
            requirement: .percentageOfEligibleDays(0.5),
            evaluationDate: date("2026-07-03")
        )

        let summary = calculator.calculate(input)

        XCTAssertEqual(summary.eligibleDaysToDate, 0)
        XCTAssertEqual(summary.completedOfficeDays, 0)
        XCTAssertNil(summary.officeShareToDate)
    }

    func testUnknownDaysAreCountedAsRequiringReview() {
        let input = input(
            attendanceDays: [
                attendance("2026-07-01", finalClassification: .unknown, officeMinutes: 0),
                attendance("2026-07-02", finalClassification: .office, officeMinutes: 180),
                attendance("2026-07-03", finalClassification: .unknown, officeMinutes: 0)
            ],
            requirement: .percentageOfEligibleDays(0.5)
        )

        let summary = calculator.calculate(input)

        XCTAssertEqual(summary.reviewRequiredDays, 2)
    }

    func testReviewRequiredDaysAreUniqueAndLimitedToAdjustedEligibleDates() {
        let input = input(
            publicHolidays: [date("2026-07-08")],
            leaveRecords: [leave("2026-07-09", type: .sickLeave)],
            attendanceDays: [
                attendance("2026-07-01", finalClassification: .unknown, officeMinutes: 0),
                attendance("2026-07-01", finalClassification: .unknown, officeMinutes: 0),
                attendance("2026-07-04", finalClassification: .unknown, officeMinutes: 0),
                attendance("2026-07-08", finalClassification: .unknown, officeMinutes: 0),
                attendance("2026-07-09", finalClassification: .unknown, officeMinutes: 0),
                attendance("2026-08-03", finalClassification: .unknown, officeMinutes: 0)
            ],
            requirement: .percentageOfEligibleDays(0.5)
        )

        let summary = calculator.calculate(input)

        XCTAssertEqual(summary.reviewRequiredDays, 1)
    }

    func testEvaluationDateCountsUnknownAndMissingEligibleDatesBeforeTodayForReview() {
        let input = input(
            attendanceDays: [
                attendance("2026-07-01", finalClassification: .office, officeMinutes: 180),
                attendance("2026-07-02", finalClassification: .unknown, officeMinutes: 0),
                attendance("2026-07-06", finalClassification: .home, officeMinutes: 0),
                attendance("2026-07-07", finalClassification: .unknown, officeMinutes: 0),
                attendance("2026-07-08", finalClassification: .unknown, officeMinutes: 0)
            ],
            requirement: .percentageOfEligibleDays(0.5),
            evaluationDate: date("2026-07-07")
        )

        let summary = calculator.calculate(input)

        // July 2 is unknown and July 3 has no record. July 7 is today, so it is not overdue.
        XCTAssertEqual(summary.reviewRequiredDays, 2)
    }

    private func input(
        publicHolidays: Set<Date> = [],
        leaveRecords: [ComplianceCalculator.LeaveRecord] = [],
        customExcludedDates: Set<Date> = [],
        attendanceDays: [ComplianceCalculator.AttendanceDay] = [],
        requirement: ComplianceCalculator.Requirement,
        minimumOfficeMinutes: Int = 180,
        evaluationDate: Date? = nil
    ) -> ComplianceCalculator.Input {
        ComplianceCalculator.Input(
            periodStart: date("2026-07-01"),
            periodEnd: date("2026-07-31"),
            calendar: calendar,
            selectedISOWeekdays: [1, 2, 3, 4, 5],
            publicHolidays: publicHolidays,
            leaveRecords: leaveRecords,
            customExcludedDates: customExcludedDates,
            attendanceDays: attendanceDays,
            requirement: requirement,
            minimumOfficeMinutes: minimumOfficeMinutes,
            evaluationDate: evaluationDate
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
