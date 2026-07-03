import XCTest
@testable import TrackWork

final class ReportSnapshotBuilderTests: XCTestCase {
    private var calendar: Calendar!
    private var builder: ReportSnapshotBuilder!

    override func setUp() {
        super.setUp()

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
        builder = ReportSnapshotBuilder()
    }

    override func tearDown() {
        calendar = nil
        builder = nil

        super.tearDown()
    }

    func testNotesAreExcludedWhenIncludeNotesIsFalse() throws {
        let attendanceDayId = UUID()
        let attendanceDay = AttendanceDay(
            id: attendanceDayId,
            date: date("2026-07-06"),
            detectedClassification: .home,
            finalClassification: .office,
            manualClassification: .office,
            complianceTreatment: .countsAsOffice,
            officeMinutes: 240,
            homeMinutes: 0,
            note: "Worked from client office"
        )
        let leaveRecord = LeaveRecord(
            date: date("2026-07-07"),
            leaveType: .annualLeave,
            note: "Family day"
        )
        let manualAdjustment = ManualAdjustment(
            attendanceDayId: attendanceDayId,
            adjustedClassification: .office,
            reason: .manualCorrection,
            note: "Corrected after review"
        )

        let snapshot = try builder.build(
            input(
                attendanceDays: [attendanceDay],
                leaveRecords: [leaveRecord],
                manualAdjustments: [manualAdjustment],
                options: ReportSnapshot.Options(includeNotes: false)
            )
        )

        XCTAssertTrue(snapshot.noteRows.isEmpty)
        XCTAssertNil(snapshot.dailyRecords.first { $0.isoDate == "2026-07-06" }?.note)
        XCTAssertNil(snapshot.leaveRows.first?.note)
        XCTAssertNil(snapshot.manualAdjustmentRows.first?.note)
    }

    func testLeaveSummaryTotalsAnnualAndSickLeaveEligibleDays() throws {
        let snapshot = try builder.build(
            input(
                leaveRecords: [
                    leave("2026-07-06", type: .annualLeave),
                    leave("2026-07-07", type: .annualLeave),
                    leave("2026-07-08", type: .sickLeave),
                    leave("2026-07-11", type: .sickLeave)
                ]
            )
        )

        XCTAssertEqual(snapshot.summary.leaveSummary.annualLeaveDays, 2)
        XCTAssertEqual(snapshot.summary.leaveSummary.sickLeaveDays, 1)
        XCTAssertEqual(snapshot.summary.leaveSummary.totalLeaveDays, 3)
    }

    func testSummaryIncludesAdjustedEligibleDaysAndAdjustedRequiredDays() throws {
        let snapshot = try builder.build(
            input(
                leaveRecords: [
                    leave("2026-07-06", type: .annualLeave),
                    leave("2026-07-07", type: .annualLeave),
                    leave("2026-07-08", type: .annualLeave),
                    leave("2026-07-09", type: .sickLeave)
                ]
            )
        )

        XCTAssertEqual(snapshot.summary.baseEligibleDays, 23)
        XCTAssertEqual(snapshot.summary.adjustedEligibleDays, 19)
        XCTAssertEqual(snapshot.summary.adjustedRequiredOfficeDays, 9)
    }

    func testSnapshotBuildsDailyHolidayLeaveOverrideAndRuleRowsForMonth() throws {
        let attendanceDayId = UUID()
        let attendanceDay = AttendanceDay(
            id: attendanceDayId,
            date: date("2026-07-06"),
            detectedClassification: .home,
            finalClassification: .office,
            manualClassification: .office,
            complianceTreatment: .countsAsOffice,
            officeMinutes: 240,
            homeMinutes: 0,
            note: "Approved correction"
        )
        let publicHoliday = PublicHoliday(
            date: date("2026-07-10"),
            name: "Example holiday",
            country: .australia,
            jurisdictionId: "AU-VIC",
            isRegional: false,
            sourceName: "Fixture"
        )

        let snapshot = try builder.build(
            input(
                attendanceDays: [attendanceDay],
                leaveRecords: [leave("2026-07-07", type: .annualLeave)],
                manualAdjustments: [
                    ManualAdjustment(
                        attendanceDayId: attendanceDayId,
                        adjustedClassification: .office,
                        reason: .manualCorrection,
                        note: "Approved correction"
                    )
                ],
                publicHolidays: [publicHoliday]
            )
        )

        XCTAssertEqual(snapshot.dailyRecords.count, 31)
        XCTAssertEqual(snapshot.leaveRows.count, 1)
        XCTAssertEqual(snapshot.manualAdjustmentRows.count, 1)
        XCTAssertEqual(snapshot.publicHolidayRows.count, 1)
        XCTAssertEqual(snapshot.ruleSummary.jurisdictionId, "AU-VIC")
        XCTAssertEqual(snapshot.ruleSummary.fixedRequiredDays, 10)
    }

    private func input(
        attendanceDays: [AttendanceDay] = [],
        leaveRecords: [LeaveRecord] = [],
        manualAdjustments: [ManualAdjustment] = [],
        publicHolidays: [PublicHoliday] = [],
        options: ReportSnapshot.Options = ReportSnapshot.Options(includeNotes: true)
    ) -> ReportSnapshotBuilder.Input {
        ReportSnapshotBuilder.Input(
            month: date("2026-07-01"),
            calendar: calendar,
            rule: ComplianceRule(
                country: .australia,
                jurisdictionId: "AU-VIC",
                requirementType: .fixedMonthlyDays,
                fixedRequiredDays: 10,
                prorateFixedTargetForLeave: true,
                minimumOfficeMinutes: 180,
                selectedISOWeekdays: [1, 2, 3, 4, 5]
            ),
            attendanceDays: attendanceDays,
            leaveRecords: leaveRecords,
            manualAdjustments: manualAdjustments,
            publicHolidays: publicHolidays,
            options: options,
            generatedAt: date("2026-07-31")
        )
    }

    private func leave(_ isoDate: String, type: LeaveType) -> LeaveRecord {
        LeaveRecord(
            date: date(isoDate),
            leaveType: type,
            duration: .fullDay
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
