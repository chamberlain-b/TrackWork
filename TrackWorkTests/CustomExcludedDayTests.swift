import SwiftData
import XCTest
@testable import TrackWork

@MainActor
final class CustomExcludedDayTests: XCTestCase {
    func testCustomExcludedDayPersistsLocallyWithOptionalReason() throws {
        let schema = Schema([CustomExcludedDay.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let excludedDay = CustomExcludedDay(
            date: Date(timeIntervalSince1970: 1_783_382_400),
            reason: "  Company closure  "
        )

        context.insert(excludedDay)
        try context.save()

        let storedDays = try context.fetch(FetchDescriptor<CustomExcludedDay>())
        XCTAssertEqual(storedDays.count, 1)
        XCTAssertEqual(storedDays.first?.reason, "Company closure")
    }
}

final class CalendarDayPresentationTests: XCTestCase {
    private var calendar: Calendar!
    private var referenceDate: Date!

    override func setUp() {
        super.setUp()

        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        self.calendar = calendar
        referenceDate = date(year: 2026, month: 7, day: 15)
    }

    override func tearDown() {
        referenceDate = nil
        calendar = nil
        super.tearDown()
    }

    func testScheduledPastUnknownDayNeedsReview() {
        let presentation = makePresentation(
            date: date(year: 2026, month: 7, day: 7)
        )

        assertKind(presentation, is: .review)
        XCTAssertEqual(presentation.systemImage, "exclamationmark")
        XCTAssertEqual(presentation.label, "Needs review")
    }

    func testScheduledCurrentDayDoesNotNeedReviewYet() {
        let presentation = makePresentation(date: referenceDate)

        assertKind(presentation, is: .upcoming)
        XCTAssertNil(presentation.systemImage)
        XCTAssertEqual(presentation.label, "Upcoming workday")
    }

    func testPastNonSelectedWeekdayIsNotRequired() {
        let presentation = makePresentation(
            date: date(year: 2026, month: 7, day: 11)
        )

        assertKind(presentation, is: .notRequired)
        XCTAssertNil(presentation.systemImage)
        XCTAssertEqual(presentation.label, "Not a scheduled workday")
    }

    func testPublicHolidayTakesPrecedenceOverLeaveExclusionAndAttendance() {
        let subjectDate = date(year: 2026, month: 7, day: 7)
        let presentation = makePresentation(
            date: subjectDate,
            attendanceDay: AttendanceDay(
                date: subjectDate,
                detectedClassification: .office,
                finalClassification: .office,
                complianceTreatment: .countsAsOffice
            ),
            leaveRecord: LeaveRecord(date: subjectDate, leaveType: .annualLeave),
            publicHoliday: PublicHoliday(
                date: subjectDate,
                name: "Test Holiday",
                country: .australia,
                jurisdictionId: "AU-VIC",
                isRegional: false,
                sourceName: "Test fixture"
            ),
            customExcludedDay: CustomExcludedDay(date: subjectDate)
        )

        assertKind(presentation, is: .publicHoliday)
        XCTAssertEqual(presentation.systemImage, "sparkles")
        XCTAssertEqual(presentation.label, "Public holiday, Test Holiday")
    }

    func testLeaveTakesPrecedenceOverExclusionAndAttendance() {
        let subjectDate = date(year: 2026, month: 7, day: 7)
        let presentation = makePresentation(
            date: subjectDate,
            attendanceDay: AttendanceDay(
                date: subjectDate,
                detectedClassification: .office,
                finalClassification: .office,
                complianceTreatment: .countsAsOffice
            ),
            leaveRecord: LeaveRecord(date: subjectDate, leaveType: .annualLeave),
            customExcludedDay: CustomExcludedDay(date: subjectDate)
        )

        assertKind(presentation, is: .annualLeave)
        XCTAssertEqual(presentation.systemImage, "sun.max.fill")
        XCTAssertEqual(presentation.label, LeaveType.annualLeave.displayName)
    }

    func testCustomExclusionTakesPrecedenceOverAttendance() {
        let subjectDate = date(year: 2026, month: 7, day: 7)
        let presentation = makePresentation(
            date: subjectDate,
            attendanceDay: AttendanceDay(
                date: subjectDate,
                detectedClassification: .office,
                finalClassification: .office,
                complianceTreatment: .countsAsOffice
            ),
            customExcludedDay: CustomExcludedDay(date: subjectDate)
        )

        assertKind(presentation, is: .excluded)
        XCTAssertEqual(presentation.systemImage, "calendar.badge.minus")
        XCTAssertEqual(presentation.label, "Custom exclusion")
    }

    func testPlannedOfficeDayIsVisibleBeforeAttendanceIsConfirmed() {
        let subjectDate = date(year: 2026, month: 7, day: 20)
        let presentation = makePresentation(
            date: subjectDate,
            plannedOfficeDay: PlannedOfficeDay(date: subjectDate)
        )

        assertKind(presentation, is: .planned)
        XCTAssertEqual(presentation.systemImage, "calendar.badge.clock")
        XCTAssertEqual(presentation.label, "Planned office day")
    }

    func testConfirmedAttendanceTakesPrecedenceOverPlan() {
        let subjectDate = date(year: 2026, month: 7, day: 14)
        let presentation = makePresentation(
            date: subjectDate,
            attendanceDay: AttendanceDay(
                date: subjectDate,
                detectedClassification: .office,
                finalClassification: .office,
                complianceTreatment: .countsAsOffice
            ),
            plannedOfficeDay: PlannedOfficeDay(date: subjectDate)
        )

        assertKind(presentation, is: .office)
        XCTAssertEqual(presentation.label, AttendanceClassification.office.displayName)
    }

    private func makePresentation(
        date: Date,
        attendanceDay: AttendanceDay? = nil,
        leaveRecord: LeaveRecord? = nil,
        publicHoliday: PublicHoliday? = nil,
        customExcludedDay: CustomExcludedDay? = nil,
        plannedOfficeDay: PlannedOfficeDay? = nil
    ) -> CalendarDayPresentation {
        CalendarDayPresentation(
            date: date,
            attendanceDay: attendanceDay,
            leaveRecord: leaveRecord,
            publicHoliday: publicHoliday,
            customExcludedDay: customExcludedDay,
            plannedOfficeDay: plannedOfficeDay,
            selectedISOWeekdays: [1, 2, 3, 4, 5],
            calendar: calendar,
            referenceDate: referenceDate
        )
    }

    private func assertKind(
        _ presentation: CalendarDayPresentation,
        is expectedKind: CalendarDayPresentation.Kind,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard kindsMatch(presentation.kind, expectedKind) else {
            XCTFail(
                "Expected calendar day kind \(expectedKind), got \(presentation.kind)",
                file: file,
                line: line
            )
            return
        }
    }

    private func kindsMatch(
        _ first: CalendarDayPresentation.Kind,
        _ second: CalendarDayPresentation.Kind
    ) -> Bool {
        switch (first, second) {
        case (.office, .office),
             (.home, .home),
             (.mixed, .mixed),
             (.annualLeave, .annualLeave),
             (.sickLeave, .sickLeave),
             (.publicHoliday, .publicHoliday),
             (.excluded, .excluded),
             (.planned, .planned),
             (.review, .review),
             (.notRequired, .notRequired),
             (.upcoming, .upcoming):
            true
        default:
            false
        }
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
            XCTFail("Invalid test fixture date: \(year)-\(month)-\(day)")
            return Date(timeIntervalSince1970: 0)
        }

        return date
    }
}
