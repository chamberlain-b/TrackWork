import PDFKit
import XCTest
@testable import TrackWork

final class PDFExportServiceTests: XCTestCase {
    private var calendar: Calendar!
    private var service: PDFExportService!

    override func setUp() {
        super.setUp()

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
        service = PDFExportService()
    }

    override func tearDown() {
        calendar = nil
        service = nil

        super.tearDown()
    }

    func testPDFIncludesRequiredMonthlyReportSectionsAndAdjustedCounts() throws {
        let data = service.makePDF(from: snapshot(includeNotes: true))
        let text = try extractedText(from: data)

        XCTAssertTrue(data.starts(with: Data("%PDF".utf8)))
        XCTAssertTrue(text.contains("Work Track Monthly Report"))
        XCTAssertTrue(text.contains("Period"))
        XCTAssertTrue(text.contains("Jurisdiction"))
        XCTAssertTrue(text.contains("Compliance Rule Summary"))
        XCTAssertTrue(text.contains("Compliance Result"))
        XCTAssertTrue(text.contains("Business Day Calculation"))
        XCTAssertTrue(text.contains("Leave Summary"))
        XCTAssertTrue(text.contains("Day-by-Day Table"))
        XCTAssertTrue(text.contains("Manual Notes and Overrides"))
        XCTAssertTrue(text.contains("Public Holiday Source Summary"))
        XCTAssertTrue(text.contains("Adjusted eligible days"))
        XCTAssertTrue(text.contains("Adjusted required office days"))
        XCTAssertTrue(text.contains("19"))
        XCTAssertTrue(text.contains("9"))
        XCTAssertTrue(text.contains("Raw location events included"))
        XCTAssertTrue(text.contains("GPS coordinates included"))
    }

    func testPDFExcludesNotesWhenIncludeNotesIsFalse() throws {
        let text = try extractedText(from: service.makePDF(from: snapshot(includeNotes: false)))

        XCTAssertFalse(text.contains("Worked from client office, level 2"))
        XCTAssertFalse(text.contains("Leave note that should stay private"))
        XCTAssertFalse(text.contains("Manual note that should stay private"))
        XCTAssertTrue(text.contains("Notes included"))
        XCTAssertTrue(text.contains("No"))
    }

    func testGeneratedFilenameUsesReportMonth() {
        XCTAssertEqual(service.fileName(for: snapshot(includeNotes: true)), "WorkTrack_2026-07.pdf")
    }

    private func extractedText(from data: Data) throws -> String {
        let document = try XCTUnwrap(PDFDocument(data: data))
        return document.string ?? ""
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
            noteRows: includeNotes ? [
                ReportSnapshot.NoteRow(
                    id: attendanceId,
                    date: date("2026-07-06"),
                    isoDate: "2026-07-06",
                    source: .attendanceDay,
                    text: "Worked from client office, level 2"
                )
            ] : [],
            publicHolidayRows: [
                ReportSnapshot.PublicHolidayRow(
                    id: UUID(),
                    date: date("2026-07-10"),
                    isoDate: "2026-07-10",
                    name: "Example special holiday",
                    countryCode: "AU",
                    jurisdictionId: "AU-VIC",
                    isRegional: false,
                    sourceName: "Fixture",
                    sourceURL: "https://example.com/holiday-source"
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
