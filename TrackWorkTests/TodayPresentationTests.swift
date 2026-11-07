import XCTest
@testable import TrackWork

final class TodayPresentationTests: XCTestCase {
    private var calendar: Calendar!
    private var builder: TodayPresentationBuilder!
    private var referenceDate: Date!

    override func setUp() {
        super.setUp()

        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_AU")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        self.calendar = calendar
        builder = TodayPresentationBuilder()
        referenceDate = date(year: 2026, month: 8, day: 5)
    }

    override func tearDown() {
        referenceDate = nil
        builder = nil
        calendar = nil
        super.tearDown()
    }

    func testRunwayUsesConfirmedDaysAgainstAdjustedTarget() {
        let attendanceDay = AttendanceDay(
            date: referenceDate,
            detectedClassification: .home,
            finalClassification: .office,
            manualClassification: .office,
            complianceTreatment: .countsAsOffice
        )
        let presentation = makePresentation(
            summary: summary(completed: 2, required: 13),
            attendanceDays: [attendanceDay]
        )

        XCTAssertEqual(presentation.status.kind, .office)
        XCTAssertEqual(presentation.status.source, "Manually corrected")
        XCTAssertEqual(presentation.remainingOfficeDays, 11)
        XCTAssertEqual(presentation.runwayTitle, "11 office days to go")
        XCTAssertEqual(presentation.progressDetail, "2 of 13 office days recorded")
        XCTAssertEqual(presentation.targetProgress, 2.0 / 13.0, accuracy: 0.0001)
    }

    func testWeekAlwaysUsesMondayThroughSundayAndMarksToday() {
        let presentation = makePresentation(summary: summary(completed: 0, required: 10))

        XCTAssertEqual(presentation.weekDays.count, 7)
        XCTAssertEqual(calendar.isoWeekday(for: presentation.weekDays[0].date), 1)
        XCTAssertEqual(calendar.isoWeekday(for: presentation.weekDays[6].date), 7)
        XCTAssertEqual(presentation.weekDays.filter(\.isToday).count, 1)
        XCTAssertEqual(
            presentation.weekDays.first(where: \.isToday)?.date,
            calendar.startOfDay(for: referenceDate)
        )
    }

    func testPublicHolidayTakesPrecedenceForTodayStatus() {
        let attendanceDay = AttendanceDay(
            date: referenceDate,
            detectedClassification: .office,
            finalClassification: .office,
            complianceTreatment: .countsAsOffice
        )
        let holiday = PublicHoliday(
            date: referenceDate,
            name: "Test Holiday",
            country: .australia,
            jurisdictionId: "AU-VIC",
            isRegional: false,
            sourceName: "Test"
        )
        let presentation = makePresentation(
            summary: summary(completed: 1, required: 10),
            attendanceDays: [attendanceDay],
            leaveRecords: [LeaveRecord(date: referenceDate, leaveType: .annualLeave)],
            publicHolidays: [holiday],
            customExcludedDays: [CustomExcludedDay(date: referenceDate)]
        )

        XCTAssertEqual(presentation.status.kind, .publicHoliday)
        XCTAssertEqual(presentation.status.title, "Public holiday")
        XCTAssertEqual(presentation.status.source, "Test Holiday")
        XCTAssertEqual(presentation.correctionTitle, "Review today")
    }

    func testPlannedTodayIsNotPresentedAsConfirmedOfficeAttendance() {
        let presentation = makePresentation(
            summary: summary(completed: 2, required: 10),
            plannedOfficeDays: [PlannedOfficeDay(date: referenceDate)]
        )

        XCTAssertEqual(presentation.status.kind, .planned)
        XCTAssertEqual(presentation.status.title, "Office planned")
        XCTAssertEqual(presentation.completedOfficeDays, 2)
        XCTAssertEqual(presentation.remainingOfficeDays, 8)
        XCTAssertEqual(presentation.correctionTitle, "Record today")
    }

    func testRecordedShareUsesCurrentMonthsRecordedWorkdaysRatherThanTarget() {
        referenceDate = date(year: 2026, month: 10, day: 3)
        let presentation = makePresentation(
            summary: summary(completed: 1, required: 8),
            attendanceDays: [
                attendance(year: 2026, month: 9, day: 30, status: .office),
                attendance(year: 2026, month: 10, day: 1, status: .home),
                attendance(year: 2026, month: 10, day: 2, status: .office)
            ]
        )

        XCTAssertEqual(presentation.recordedWorkdayShare, "50%")
        XCTAssertEqual(presentation.recordedWorkdayDetail, "of recorded workdays · 1 of 2")
        XCTAssertEqual(presentation.progressDetail, "1 of 8 office days recorded")
        XCTAssertEqual(presentation.targetProgress, 0.125)
        XCTAssertEqual(presentation.runwayTitle, "7 office days to go")
        XCTAssertEqual(presentation.status.kind, .notRequired)
    }

    func testRecordedShareUsesExistingMixedThresholdAndExcludesNonworkingDays() {
        referenceDate = date(year: 2026, month: 8, day: 7)
        let presentation = makePresentation(
            summary: summary(completed: 1, required: 8),
            attendanceDays: [
                attendance(day: 1, status: .office), // Saturday
                attendance(day: 3, status: .office), // Leave
                attendance(day: 4, status: .office), // Public holiday
                attendance(day: 5, status: .office), // Custom exclusion
                attendance(day: 6, status: .mixed, officeMinutes: 179),
                attendance(day: 7, status: .mixed, officeMinutes: 180),
                attendance(day: 10, status: .office) // Future
            ],
            leaveRecords: [LeaveRecord(date: date(year: 2026, month: 8, day: 3), leaveType: .annualLeave)],
            publicHolidays: [PublicHoliday(
                date: date(year: 2026, month: 8, day: 4), name: "Test holiday",
                country: .australia, jurisdictionId: "AU-VIC", isRegional: false, sourceName: "Test"
            )],
            customExcludedDays: [CustomExcludedDay(date: date(year: 2026, month: 8, day: 5))]
        )

        XCTAssertEqual(presentation.monthlyAttendanceMix, AttendanceMix(officeDays: 1, homeDays: 1))
        XCTAssertEqual(presentation.recordedWorkdayShare, "50%")
        XCTAssertEqual(presentation.recordedWorkdayDetail, "of recorded workdays · 1 of 2")
    }

    func testNoRecordedWorkdaysDoesNotPresentZeroPercent() {
        let presentation = makePresentation(
            summary: summary(completed: 0, required: 8),
            attendanceDays: [attendance(day: 3, status: .unknown), attendance(day: 10, status: .office)]
        )

        XCTAssertEqual(presentation.recordedWorkdayShare, "—")
        XCTAssertEqual(presentation.recordedWorkdayDetail, "No recorded workdays yet")
    }

    func testRecordedHomeDayPresentsRealZeroPercent() {
        let presentation = makePresentation(
            summary: summary(completed: 0, required: 8),
            attendanceDays: [attendance(day: 3, status: .home)]
        )

        XCTAssertEqual(presentation.recordedWorkdayShare, "0%")
        XCTAssertEqual(presentation.recordedWorkdayDetail, "of recorded workdays · 0 of 1")
    }

    private func attendance(
        year: Int = 2026, month: Int = 8, day: Int,
        status: AttendanceClassification, officeMinutes: Int = 420
    ) -> AttendanceDay {
        AttendanceDay(
            date: date(year: year, month: month, day: day),
            detectedClassification: status, finalClassification: status,
            complianceTreatment: ComplianceTreatmentResolver.resolve(
                classification: status, officeMinutes: officeMinutes, minimumOfficeMinutes: 180
            ),
            officeMinutes: status == .home ? 0 : officeMinutes,
            homeMinutes: status == .home || status == .mixed ? 420 : 0
        )
    }

    private func makePresentation(
        summary: ComplianceSummary,
        attendanceDays: [AttendanceDay] = [],
        leaveRecords: [LeaveRecord] = [],
        publicHolidays: [PublicHoliday] = [],
        customExcludedDays: [CustomExcludedDay] = [],
        plannedOfficeDays: [PlannedOfficeDay] = []
    ) -> TodayDashboardPresentation {
        builder.makePresentation(
            TodayPresentationBuilder.Input(
                referenceDate: referenceDate,
                calendar: calendar,
                summary: summary,
                attendanceDays: attendanceDays,
                leaveRecords: leaveRecords,
                publicHolidays: publicHolidays,
                customExcludedDays: customExcludedDays,
                plannedOfficeDays: plannedOfficeDays,
                selectedISOWeekdays: [1, 2, 3, 4, 5],
                jurisdictionId: "AU-VIC",
                targetIsConfigured: true,
                monthlyAttendanceMix: try? AttendancePeriodPresentationBuilder().make(.init(
                    range: ComplianceDateRange(
                        start: calendar.dashboardMonthStart(for: referenceDate),
                        end: calendar.dashboardMonthEnd(for: referenceDate),
                        calendar: calendar
                    ),
                    calendar: calendar,
                    referenceDate: referenceDate,
                    rules: [ComplianceRule(fixedRequiredDays: summary.requiredOfficeDays)],
                    attendanceDays: attendanceDays,
                    leaveRecords: leaveRecords,
                    publicHolidays: publicHolidays,
                    customExcludedDays: customExcludedDays
                )).mix
            )
        )
    }

    private func summary(completed: Int, required: Int) -> ComplianceSummary {
        ComplianceSummary(
            baseEligibleDays: 21,
            adjustedEligibleDays: 21,
            eligibleDaysToDate: 3,
            customExcludedDays: 0,
            requiredOfficeDays: required,
            completedOfficeDays: completed,
            reviewRequiredDays: 0
        )
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        guard let date = calendar.date(
            from: DateComponents(
                calendar: calendar,
                timeZone: calendar.timeZone,
                year: year,
                month: month,
                day: day
            )
        ) else {
            XCTFail("Invalid fixture date")
            return Date(timeIntervalSince1970: 0)
        }

        return date
    }
}
