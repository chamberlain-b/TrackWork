import Foundation
import Observation

@Observable
final class ReportingPeriodSelection {
    var preset: CompliancePeriodPreset = .currentMonth
    var customStart: Date
    var customEnd: Date

    init(referenceDate: Date = .now) {
        customStart = referenceDate
        customEnd = referenceDate
    }

    func range(calendar: Calendar, referenceDate: Date) -> ComplianceDateRange {
        preset.dateRange(calendar: calendar, now: referenceDate, customStart: customStart, customEnd: customEnd)
    }
}

enum InsightsSection: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case trends = "Trends"
    case breakdown = "Breakdown"

    var id: String { rawValue }
}

struct AttendanceMix: Equatable {
    let officeDays: Int
    let homeDays: Int
    var totalDays: Int { officeDays + homeDays }
    var officeShare: Double? { totalDays > 0 ? Double(officeDays) / Double(totalDays) : nil }
    var homeShare: Double? { officeShare.map { 1 - $0 } }
}

struct AttendanceHeatmapDay: Identifiable, Equatable {
    var id: Date { date }
    let date: Date
    let classification: AttendanceClassification
    let isExcluded: Bool
    let isUpcoming: Bool
    let isOverride: Bool

    var label: String {
        if isExcluded { return "Excluded day" }
        if classification == .unknown { return isUpcoming ? "Upcoming" : "Unrecorded" }
        return classification.displayName
    }
}

struct AttendancePeriodPresentation {
    let range: ComplianceDateRange
    let summary: ComplianceSummary
    let mix: AttendanceMix
    let days: [AttendanceHeatmapDay]
    let coverageWarning: String?
}

struct AttendanceTrendPresentation: Identifiable {
    var id: Date { point.id }
    let point: ComplianceTrendPoint
    let mix: AttendanceMix
}

/// Read-only adaptation of the existing report/day and compliance rules.
/// No report files, location events or persistence writes are involved.
struct AttendancePeriodPresentationBuilder {
    struct Input {
        let range: ComplianceDateRange
        let calendar: Calendar
        let referenceDate: Date
        let rules: [ComplianceRule]
        let attendanceDays: [AttendanceDay]
        let leaveRecords: [LeaveRecord]
        let publicHolidays: [PublicHoliday]
        let customExcludedDays: [CustomExcludedDay]

        func replacingRange(_ range: ComplianceDateRange) -> Input {
            Input(range: range, calendar: calendar, referenceDate: referenceDate, rules: rules,
                  attendanceDays: attendanceDays, leaveRecords: leaveRecords,
                  publicHolidays: publicHolidays, customExcludedDays: customExcludedDays)
        }
    }

    func make(_ input: Input) throws -> AttendancePeriodPresentation {
        let rule = ComplianceRuleResolver().rule(for: input.range.end, from: input.rules) ?? ComplianceRule()
        let snapshot = try ReportSnapshotBuilder().build(.init(
            range: input.range, calendar: input.calendar, rule: rule,
            attendanceDays: input.attendanceDays, leaveRecords: input.leaveRecords,
            manualAdjustments: [], publicHolidays: input.publicHolidays,
            customExcludedDays: input.customExcludedDays,
            options: .init(includeNotes: false), generatedAt: input.referenceDate
        ))
        let today = input.calendar.startOfDay(for: input.referenceDate)
        let recorded = snapshot.dailyRecords.filter { $0.date <= today }
        let mix = AttendanceMix(
            officeDays: recorded.filter { $0.complianceTreatment == .countsAsOffice }.count,
            homeDays: recorded.filter { $0.complianceTreatment == .countsAsHome }.count
        )
        let attendanceByDate = Dictionary(grouping: input.attendanceDays) {
            input.calendar.startOfDay(for: $0.date)
        }
        let leaveByDate = Dictionary(grouping: input.leaveRecords) {
            input.calendar.startOfDay(for: $0.date)
        }
        let days = snapshot.dailyRecords.map { row in
            let latest = attendanceByDate[row.date]?.sorted { $0.updatedAt < $1.updatedAt }.last
            let leave = leaveByDate[row.date]?.first { $0.duration == .fullDay }?.leaveType?.classification
                ?? ([AttendanceClassification.annualLeave, .sickLeave].contains(row.finalStatus) ? row.finalStatus : nil)
            let isHoliday = row.isPublicHoliday || row.finalStatus == .publicHoliday
            // Match Calendar's exclusion precedence without changing stored final classifications.
            let classification: AttendanceClassification
            if isHoliday {
                classification = .publicHoliday
            } else if let leave {
                classification = leave
            } else {
                classification = row.finalStatus
            }
            return AttendanceHeatmapDay(
                date: row.date, classification: classification,
                isExcluded: row.isCustomExcluded && !isHoliday && leave == nil,
                isUpcoming: row.date > today,
                isOverride: latest?.manualClassification != nil
            )
        }
        let summary = CompliancePeriodEvaluator().evaluate(.init(
            range: input.range, calendar: input.calendar, rule: rule,
            attendanceDays: input.attendanceDays, leaveRecords: input.leaveRecords,
            publicHolidays: input.publicHolidays, customExcludedDays: input.customExcludedDays,
            evaluationDate: input.referenceDate
        ))
        return AttendancePeriodPresentation(
            range: input.range, summary: summary, mix: mix, days: days,
            coverageWarning: HolidayCoverage.validation(for: input.range, calendar: input.calendar).userFacingMessage
        )
    }

    func trends(_ input: Input, granularity: ComplianceTrendGranularity) throws -> [AttendanceTrendPresentation] {
        // Keep calendar-aligned six-bucket history. Future records never enter the actuals.
        let attendance = input.attendanceDays.filter {
            input.calendar.startOfDay(for: $0.date) <= input.calendar.startOfDay(for: input.referenceDate)
        }
        let points = ComplianceTrendCalculator().points(
            granularity: granularity, endingAt: input.range.end, calendar: input.calendar,
            rules: input.rules, attendanceDays: attendance, leaveRecords: input.leaveRecords,
            publicHolidays: input.publicHolidays, customExcludedDays: input.customExcludedDays
        )
        return try points.map { point in
            AttendanceTrendPresentation(point: point, mix: try make(input.replacingRange(point.range)).mix)
        }
    }
}
