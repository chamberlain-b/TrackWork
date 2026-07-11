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
        let customExcludedDay = CustomExcludedDay(
            date: date("2026-07-08"),
            reason: "Private closure reason"
        )

        let snapshot = try builder.build(
            input(
                attendanceDays: [attendanceDay],
                leaveRecords: [leaveRecord],
                manualAdjustments: [manualAdjustment],
                customExcludedDays: [customExcludedDay],
                options: ReportSnapshot.Options(includeNotes: false)
            )
        )

        XCTAssertTrue(snapshot.noteRows.isEmpty)
        XCTAssertNil(snapshot.dailyRecords.first { $0.isoDate == "2026-07-06" }?.note)
        XCTAssertNil(snapshot.leaveRows.first?.note)
        XCTAssertNil(snapshot.customExclusionRows.first?.reason)
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

    func testSummaryCountsMissingEligibleDaysBeforeGenerationDateAsReviewRequired() throws {
        let snapshot = try builder.build(
            input(
                attendanceDays: [
                    attendance("2026-07-01", classification: .office),
                    attendance("2026-07-02", classification: .home)
                ],
                generatedAt: date("2026-07-07")
            )
        )

        XCTAssertEqual(snapshot.summary.reviewRequiredDays, 2)
    }

    func testSummaryExcludesFutureOfficeAttendanceFromCompletedDays() throws {
        let snapshot = try builder.build(
            input(
                attendanceDays: [
                    attendance("2026-07-07", classification: .office),
                    attendance("2026-07-08", classification: .office)
                ],
                generatedAt: date("2026-07-07")
            )
        )

        XCTAssertEqual(snapshot.summary.completedOfficeDays, 1)
    }

    func testMixedDayTreatmentMatchesOfficeMinuteThresholdAndComplianceTotal() throws {
        let mixedDay = AttendanceDay(
            date: date("2026-07-06"),
            detectedClassification: .mixed,
            finalClassification: .mixed,
            complianceTreatment: .countsAsHome,
            officeMinutes: 180,
            homeMinutes: 60
        )

        let snapshot = try builder.build(input(attendanceDays: [mixedDay]))
        let row = try XCTUnwrap(snapshot.dailyRecords.first { $0.isoDate == "2026-07-06" })

        XCTAssertEqual(snapshot.summary.completedOfficeDays, 1)
        XCTAssertEqual(row.finalStatus, .mixed)
        XCTAssertEqual(row.complianceTreatment, .countsAsOffice)
    }

    func testCustomExclusionUsesPeriodEvaluatorTotalsAndAppearsInBothReportSections() throws {
        let excludedDay = CustomExcludedDay(
            date: date("2026-07-06"),
            reason: "Company closure"
        )

        let snapshot = try builder.build(
            input(
                attendanceDays: [attendance("2026-07-06", classification: .office)],
                customExcludedDays: [excludedDay]
            )
        )
        let dailyRow = try XCTUnwrap(snapshot.dailyRecords.first { $0.isoDate == "2026-07-06" })
        let exclusionRow = try XCTUnwrap(snapshot.customExclusionRows.first)

        XCTAssertEqual(snapshot.summary.baseEligibleDays, 23)
        XCTAssertEqual(snapshot.summary.adjustedEligibleDays, 22)
        XCTAssertEqual(snapshot.summary.customExcludedDays, 1)
        XCTAssertEqual(snapshot.summary.completedOfficeDays, 0)
        XCTAssertTrue(dailyRow.isCustomExcluded)
        XCTAssertEqual(dailyRow.complianceTreatment, .excludedFromRequirement)
        XCTAssertEqual(exclusionRow.isoDate, "2026-07-06")
        XCTAssertTrue(exclusionRow.reducesEligibleDays)
        XCTAssertEqual(exclusionRow.reason, "Company closure")
    }

    func testNonMonthRangeIsInclusiveAndFiltersToActiveJurisdictionHolidays() throws {
        let range = ComplianceDateRange(
            start: date("2026-06-29"),
            end: date("2026-07-03"),
            calendar: calendar
        )
        let activeHoliday = PublicHoliday(
            date: date("2026-07-01"),
            name: "Active holiday",
            country: .australia,
            jurisdictionId: "AU-VIC",
            isRegional: false,
            sourceName: "Fixture"
        )
        let otherHoliday = PublicHoliday(
            date: date("2026-07-02"),
            name: "Other jurisdiction holiday",
            country: .australia,
            jurisdictionId: "AU-NSW",
            isRegional: false,
            sourceName: "Fixture"
        )
        let rule = ComplianceRule(
            country: .australia,
            jurisdictionId: "AU-VIC",
            requirementType: .percentageOfEligibleDays,
            fixedRequiredDays: nil,
            requiredPercentage: 0.5,
            selectedISOWeekdays: [1, 2, 3, 4, 5]
        )

        let snapshot = try builder.build(
            input(
                range: range,
                rule: rule,
                attendanceDays: [
                    attendance("2026-06-29", classification: .office),
                    attendance("2026-07-03", classification: .office),
                    attendance("2026-07-06", classification: .office)
                ],
                publicHolidays: [activeHoliday, otherHoliday],
                generatedAt: date("2026-07-03")
            )
        )

        XCTAssertEqual(snapshot.summary.periodStart, date("2026-06-29"))
        XCTAssertEqual(snapshot.summary.periodEnd, date("2026-07-03"))
        XCTAssertEqual(snapshot.dailyRecords.count, 5)
        XCTAssertEqual(snapshot.dailyRecords.first?.isoDate, "2026-06-29")
        XCTAssertEqual(snapshot.dailyRecords.last?.isoDate, "2026-07-03")
        XCTAssertEqual(snapshot.summary.baseEligibleDays, 4)
        XCTAssertEqual(snapshot.summary.adjustedRequiredOfficeDays, 2)
        XCTAssertEqual(snapshot.summary.completedOfficeDays, 2)
        XCTAssertEqual(snapshot.publicHolidayRows.map(\.name), ["Active holiday"])
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
        range: ComplianceDateRange? = nil,
        rule: ComplianceRule? = nil,
        attendanceDays: [AttendanceDay] = [],
        leaveRecords: [LeaveRecord] = [],
        manualAdjustments: [ManualAdjustment] = [],
        publicHolidays: [PublicHoliday] = [],
        customExcludedDays: [CustomExcludedDay] = [],
        options: ReportSnapshot.Options = ReportSnapshot.Options(includeNotes: true),
        generatedAt: Date? = nil
    ) -> ReportSnapshotBuilder.Input {
        ReportSnapshotBuilder.Input(
            range: range ?? ComplianceDateRange(
                start: date("2026-07-01"),
                end: date("2026-07-31"),
                calendar: calendar
            ),
            calendar: calendar,
            rule: rule ?? ComplianceRule(
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
            customExcludedDays: customExcludedDays,
            options: options,
            generatedAt: generatedAt ?? date("2026-07-31")
        )
    }

    private func attendance(
        _ isoDate: String,
        classification: AttendanceClassification
    ) -> AttendanceDay {
        AttendanceDay(
            date: date(isoDate),
            detectedClassification: classification,
            finalClassification: classification,
            complianceTreatment: classification == .office ? .countsAsOffice : .countsAsHome,
            officeMinutes: classification == .office ? 180 : 0,
            homeMinutes: classification == .home ? 180 : 0
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
