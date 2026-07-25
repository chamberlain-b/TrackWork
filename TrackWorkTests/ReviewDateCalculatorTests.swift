import XCTest
@testable import TrackWork

final class ReviewDateCalculatorTests: XCTestCase {
    private let calculator = ReviewDateCalculator()
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    func testPastUnknownAndMissingSelectedWorkdaysNeedReviewWhileConfirmedDayDoesNot() {
        let confirmedDay = AttendanceDay(
            date: date("2026-07-06"),
            detectedClassification: .office,
            finalClassification: .office,
            complianceTreatment: .countsAsOffice
        )
        let unknownDay = AttendanceDay(
            date: date("2026-07-07"),
            detectedClassification: .unknown,
            finalClassification: .unknown,
            complianceTreatment: .requiresReview
        )
        let input = ReviewDateCalculator.Input(
            range: range(from: "2026-07-06", through: "2026-07-08"),
            calendar: calendar,
            rule: makeRule(),
            attendanceDays: [confirmedDay, unknownDay],
            leaveRecords: [],
            publicHolidays: [],
            customExcludedDays: [],
            evaluationDate: date("2026-07-09")
        )

        XCTAssertEqual(
            calculator.datesNeedingReview(input),
            [date("2026-07-07"), date("2026-07-08")]
        )
    }

    func testTodayFutureAndWeekendDatesDoNotNeedReview() {
        let input = ReviewDateCalculator.Input(
            range: range(from: "2026-07-10", through: "2026-07-17"),
            calendar: calendar,
            rule: makeRule(),
            attendanceDays: [],
            leaveRecords: [],
            publicHolidays: [],
            customExcludedDays: [],
            evaluationDate: date("2026-07-15")
        )

        XCTAssertEqual(
            calculator.datesNeedingReview(input),
            [date("2026-07-10"), date("2026-07-13"), date("2026-07-14")]
        )
    }

    func testHolidayLeaveCustomExclusionAndConfirmedDaysDoNotNeedReview() {
        let confirmedDay = AttendanceDay(
            date: date("2026-07-09"),
            detectedClassification: .home,
            finalClassification: .home,
            complianceTreatment: .countsAsHome
        )
        let activeHoliday = PublicHoliday(
            date: date("2026-07-06"),
            name: "Active jurisdiction holiday",
            country: .australia,
            jurisdictionId: "AU-VIC",
            isRegional: false,
            sourceName: "Test"
        )
        let otherJurisdictionHoliday = PublicHoliday(
            date: date("2026-07-10"),
            name: "Other jurisdiction holiday",
            country: .australia,
            jurisdictionId: "AU-NSW",
            isRegional: false,
            sourceName: "Test"
        )
        let input = ReviewDateCalculator.Input(
            range: range(from: "2026-07-06", through: "2026-07-10"),
            calendar: calendar,
            rule: makeRule(),
            attendanceDays: [confirmedDay],
            leaveRecords: [LeaveRecord(date: date("2026-07-07"), leaveType: .annualLeave)],
            publicHolidays: [activeHoliday, otherJurisdictionHoliday],
            customExcludedDays: [CustomExcludedDay(date: date("2026-07-08"))],
            evaluationDate: date("2026-07-11")
        )

        XCTAssertEqual(calculator.datesNeedingReview(input), [date("2026-07-10")])
    }

    private func makeRule() -> ComplianceRule {
        ComplianceRule(
            country: .australia,
            jurisdictionId: "AU-VIC",
            selectedISOWeekdays: [1, 2, 3, 4, 5]
        )
    }

    private func range(from start: String, through end: String) -> ComplianceDateRange {
        ComplianceDateRange(
            start: date(start),
            end: date(end),
            calendar: calendar
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
