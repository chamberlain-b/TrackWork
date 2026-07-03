import XCTest
@testable import TrackWork

final class CSVExportServiceTests: XCTestCase {
    private var calendar: Calendar!
    private var service: CSVExportService!

    override func setUp() {
        super.setUp()

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
        service = CSVExportService()
    }

    override func tearDown() {
        calendar = nil
        service = nil

        super.tearDown()
    }

    func testCSVIncludesRequiredSectionsAndLeaveAdjustedRequirement() {
        let csv = service.makeCSV(from: snapshot(includeNotes: true))

        XCTAssertTrue(csv.contains("\"Summary\""))
        XCTAssertTrue(csv.contains("\"Daily Records\""))
        XCTAssertTrue(csv.contains("\"Leave\""))
        XCTAssertTrue(csv.contains("\"Manual Overrides and Notes\""))
        XCTAssertTrue(csv.contains("\"Public Holidays\""))
        XCTAssertTrue(csv.contains("\"Settings\""))
        XCTAssertTrue(csv.contains("\"Adjusted required office days\",\"9\""))
    }

    func testCSVEscapesSpreadsheetFields() {
        let csv = service.makeCSV(from: snapshot(includeNotes: true))

        XCTAssertTrue(csv.contains("\"Worked from client office, level 2\""))
        XCTAssertTrue(csv.contains("\"Example \"\"special\"\" holiday\""))
    }

    func testCSVExcludesNotesWhenIncludeNotesIsFalse() {
        let csv = service.makeCSV(from: snapshot(includeNotes: false))

        XCTAssertFalse(csv.contains("Worked from client office, level 2"))
        XCTAssertFalse(csv.contains("Leave note that should stay private"))
        XCTAssertFalse(csv.contains("Manual note that should stay private"))
        XCTAssertTrue(csv.contains("\"Notes included\",\"No\""))
    }

    func testGeneratedFilenameUsesReportMonth() {
        XCTAssertEqual(service.fileName(for: snapshot(includeNotes: true)), "Work Track 2026-07 Monthly Report.csv")
    }

    private func snapshot(includeNotes: Bool) -> ReportSnapshot {
        let periodStart = date("2026-07-01")
        let periodEnd = date("2026-07-31")
        let attendanceId = UUID()
        let leaveId = UUID()
        let manualAdjustmentId = UUID()

        return ReportSnapshot(
            summary: ReportSnapshot.Summary(
                periodStart: periodStart,
                periodEnd: periodEnd,
                generatedAt: date("2026-07-31"),
                baseEligibleDays: 23,
                adjustedEligibleDays: 19,
                adjustedRequiredOfficeDays: 9,
                completedOfficeDays: 7,
                reviewRequiredDays: 1,
                leaveSummary: ReportSnapshot.LeaveSummary(
                    annualLeaveDays: 3,
                    sickLeaveDays: 1,
                    totalLeaveDays: 4
                )
            ),
            dailyRecords: [
                ReportSnapshot.DailyRecordRow(
                    id: attendanceId,
                    date: date("2026-07-06"),
                    isoDate: "2026-07-06",
                    detectedStatus: .home,
                    finalStatus: .office,
                    complianceTreatment: .countsAsOffice,
                    officeMinutes: 240,
                    homeMinutes: 0,
                    isSelectedWorkday: true,
                    isPublicHoliday: false,
                    hasLeave: false,
                    note: "Worked from client office, level 2"
                )
            ],
            leaveRows: [
                ReportSnapshot.LeaveRow(
                    id: leaveId,
                    date: date("2026-07-07"),
                    isoDate: "2026-07-07",
                    type: .annualLeave,
                    duration: .fullDay,
                    countsAgainstEligibleDay: true,
                    note: "Leave note that should stay private"
                )
            ],
            manualAdjustmentRows: [
                ReportSnapshot.ManualAdjustmentRow(
                    id: manualAdjustmentId,
                    date: date("2026-07-06"),
                    isoDate: "2026-07-06",
                    adjustedClassification: .office,
                    reason: .manualCorrection,
                    note: "Manual note that should stay private"
                )
            ],
            noteRows: [
                ReportSnapshot.NoteRow(
                    id: attendanceId,
                    date: date("2026-07-06"),
                    isoDate: "2026-07-06",
                    source: .attendanceDay,
                    text: "Worked from client office, level 2"
                )
            ],
            publicHolidayRows: [
                ReportSnapshot.PublicHolidayRow(
                    id: UUID(),
                    date: date("2026-07-10"),
                    isoDate: "2026-07-10",
                    name: "Example \"special\" holiday",
                    countryCode: "AU",
                    jurisdictionId: "AU-VIC",
                    isRegional: false,
                    sourceName: "Fixture",
                    sourceURL: "https://example.com/holiday,source"
                )
            ],
            ruleSummary: ReportSnapshot.RuleSummary(
                ruleName: "Default Monthly Rule",
                countryCode: "AU",
                jurisdictionId: "AU-VIC",
                requirementType: .fixedMonthlyDays,
                fixedRequiredDays: 10,
                requiredPercentage: nil,
                prorateFixedTargetForLeave: true,
                minimumOfficeMinutes: 180,
                selectedISOWeekdays: [1, 2, 3, 4, 5]
            ),
            options: ReportSnapshot.Options(includeNotes: includeNotes)
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
