import XCTest
@testable import TrackWork

final class CompliancePeriodTests: XCTestCase {
    private struct ExpectedRange {
        let preset: CompliancePeriodPreset
        let start: String
        let end: String
    }

    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
    }

    override func tearDown() {
        calendar = nil
        super.tearDown()
    }

    func testBuiltInRangesHaveDeterministicInclusiveBoundaries() {
        let now = date("2026-07-15")
        let expectedRanges = [
            ExpectedRange(preset: .currentMonth, start: "2026-07-01", end: "2026-07-31"),
            ExpectedRange(preset: .last30Days, start: "2026-06-16", end: "2026-07-15"),
            ExpectedRange(preset: .previousMonth, start: "2026-06-01", end: "2026-06-30"),
            ExpectedRange(preset: .currentQuarter, start: "2026-07-01", end: "2026-09-30"),
            ExpectedRange(preset: .previousQuarter, start: "2026-04-01", end: "2026-06-30"),
            ExpectedRange(preset: .yearToDate, start: "2026-01-01", end: "2026-07-15")
        ]

        for expected in expectedRanges {
            let range = expected.preset.dateRange(
                calendar: calendar,
                now: now,
                customStart: now,
                customEnd: now
            )

            XCTAssertEqual(range.start, date(expected.start), expected.preset.rawValue)
            XCTAssertEqual(range.end, date(expected.end), expected.preset.rawValue)
            XCTAssertTrue(
                range.contains(range.start, calendar: calendar),
                expected.preset.rawValue
            )
            XCTAssertTrue(
                range.contains(range.end, calendar: calendar),
                expected.preset.rawValue
            )
        }
    }

    func testCustomRangeNormalizesDayTimesAndReversedInput() {
        let later = date("2026-07-10").addingTimeInterval(60 * 60 * 18)
        let earlier = date("2026-07-05").addingTimeInterval(60 * 60 * 8)

        let range = CompliancePeriodPreset.custom.dateRange(
            calendar: calendar,
            now: date("2026-07-15"),
            customStart: later,
            customEnd: earlier
        )

        XCTAssertEqual(range.start, date("2026-07-05"))
        XCTAssertEqual(range.end, date("2026-07-10"))
        XCTAssertTrue(range.contains(date("2026-07-05"), calendar: calendar))
        XCTAssertTrue(range.contains(date("2026-07-10").addingTimeInterval(86_399), calendar: calendar))
        XCTAssertFalse(range.contains(date("2026-07-11"), calendar: calendar))
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

final class OfficePlanCandidateDateCalculatorTests: XCTestCase {
    private let calculator = OfficePlanCandidateDateCalculator()
    private let calendar = Calendar.workTrackCalendar

    func testFutureAttendanceRemainsAvailableUntilTheEvaluationDate() {
        let futureOfficeDate = date(2026, 7, 30)
        let range = ComplianceDateRange(
            start: date(2026, 7, 1),
            end: date(2026, 7, 31),
            calendar: calendar
        )

        let result = calculator.candidateDates(
            OfficePlanCandidateDateCalculator.Input(
                range: range,
                calendar: calendar,
                rule: ComplianceRule(fixedRequiredDays: 8),
                attendanceDays: [
                    AttendanceDay(
                        date: futureOfficeDate,
                        detectedClassification: .office,
                        finalClassification: .office,
                        complianceTreatment: .countsAsOffice,
                        officeMinutes: 420
                    )
                ],
                leaveRecords: [],
                publicHolidays: [],
                customExcludedDays: [],
                evaluationDate: date(2026, 7, 29)
            )
        )

        XCTAssertTrue(result.contains(futureOfficeDate))
    }

    func testLeaveHolidayAndCustomExclusionAreNotPlanCandidates() {
        let leaveDate = date(2026, 8, 11)
        let excludedDate = date(2026, 8, 14)
        let holidayDate = date(2026, 8, 28)
        let range = ComplianceDateRange(
            start: date(2026, 8, 1),
            end: date(2026, 8, 31),
            calendar: calendar
        )

        let result = calculator.candidateDates(
            OfficePlanCandidateDateCalculator.Input(
                range: range,
                calendar: calendar,
                rule: ComplianceRule(fixedRequiredDays: 8),
                attendanceDays: [],
                leaveRecords: [
                    LeaveRecord(date: leaveDate, leaveType: .annualLeave)
                ],
                publicHolidays: [
                    PublicHoliday(
                        date: holidayDate,
                        name: "Test holiday",
                        country: .australia,
                        jurisdictionId: "AU-VIC",
                        isRegional: true,
                        sourceName: "Unit test"
                    )
                ],
                customExcludedDays: [
                    CustomExcludedDay(date: excludedDate, reason: "Office closed")
                ],
                evaluationDate: date(2026, 7, 29)
            )
        )

        XCTAssertFalse(result.contains(leaveDate))
        XCTAssertFalse(result.contains(excludedDate))
        XCTAssertFalse(result.contains(holidayDate))
        XCTAssertTrue(result.contains(date(2026, 8, 31)))
    }

    func testMalformedLeaveRecordDoesNotRemoveAPlanCandidate() {
        let malformedLeaveDate = date(2026, 8, 11)
        let malformedLeave = LeaveRecord(
            date: malformedLeaveDate,
            leaveType: .annualLeave
        )
        malformedLeave.leaveTypeRaw = "unsupported"

        let result = calculator.candidateDates(
            OfficePlanCandidateDateCalculator.Input(
                range: ComplianceDateRange(
                    start: date(2026, 8, 1),
                    end: date(2026, 8, 31),
                    calendar: calendar
                ),
                calendar: calendar,
                rule: ComplianceRule(fixedRequiredDays: 8),
                attendanceDays: [],
                leaveRecords: [malformedLeave],
                publicHolidays: [],
                customExcludedDays: [],
                evaluationDate: date(2026, 7, 29)
            )
        )

        XCTAssertTrue(result.contains(malformedLeaveDate))
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}

final class OfficePlanReconciliationServiceTests: XCTestCase {
    private let service = OfficePlanReconciliationService()
    private let calendar = Calendar.workTrackCalendar

    func testReplanPreservesAllRecordsAndNotesForDatesThatRemainSelected() {
        let retainedDate = date(2026, 8, 5)
        let removedDate = date(2026, 8, 12)
        let insertedDate = date(2026, 8, 19)
        let firstRetainedPlan = PlannedOfficeDay(
            date: retainedDate,
            note: "Client workshop"
        )
        let duplicateRetainedPlan = PlannedOfficeDay(
            date: retainedDate,
            note: "Train booking"
        )
        let removedPlan = PlannedOfficeDay(date: removedDate, note: "Old plan")

        let result = service.changes(
            existingPlans: [firstRetainedPlan, duplicateRetainedPlan, removedPlan],
            desiredDates: [retainedDate, insertedDate],
            range: ComplianceDateRange(
                start: date(2026, 8, 1),
                end: date(2026, 8, 31),
                calendar: calendar
            ),
            calendar: calendar
        )

        XCTAssertEqual(result.plansToDelete.map(\.id), [removedPlan.id])
        XCTAssertEqual(result.datesToInsert, [insertedDate])
        XCTAssertFalse(result.plansToDelete.contains { $0.id == firstRetainedPlan.id })
        XCTAssertFalse(result.plansToDelete.contains { $0.id == duplicateRetainedPlan.id })
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
