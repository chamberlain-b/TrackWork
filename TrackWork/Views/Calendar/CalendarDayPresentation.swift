import SwiftUI

struct CalendarDayPresentation {
    enum Kind {
        case office
        case home
        case mixed
        case annualLeave
        case sickLeave
        case publicHoliday
        case excluded
        case planned
        case review
        case notRequired
        case upcoming
    }

    let kind: Kind
    let systemImage: String?
    let label: String
    let color: Color

    var cellBackground: Color {
        switch kind {
        case .review:
            color.opacity(0.045)
        case .office, .home, .mixed, .annualLeave, .sickLeave, .publicHoliday, .excluded, .planned:
            color.opacity(0.035)
        case .notRequired, .upcoming:
            Color.clear
        }
    }

    var isQuiet: Bool {
        kind == .notRequired || kind == .upcoming
    }

    init(
        date: Date,
        attendanceDay: AttendanceDay?,
        leaveRecord: LeaveRecord?,
        publicHoliday: PublicHoliday?,
        customExcludedDay: CustomExcludedDay?,
        plannedOfficeDay: PlannedOfficeDay?,
        selectedISOWeekdays: Set<Int>,
        calendar: Calendar,
        referenceDate: Date
    ) {
        let finalClassification = attendanceDay?.finalClassification ?? .unknown
        let recordedLeave = leaveRecord?.leaveType ?? finalClassification.leaveType
        let presentation = Self.recordedPresentation(
            finalClassification: finalClassification,
            recordedLeave: recordedLeave,
            publicHoliday: publicHoliday,
            customExcludedDay: customExcludedDay
        ) ?? Self.schedulePresentation(
            ScheduleContext(
                date: date,
                finalClassification: finalClassification,
                hasOfficePlan: plannedOfficeDay != nil,
                selectedISOWeekdays: selectedISOWeekdays,
                calendar: calendar,
                referenceDate: referenceDate
            )
        )

        kind = presentation.kind
        systemImage = presentation.systemImage
        label = presentation.label
        color = presentation.color
    }
}

private extension CalendarDayPresentation {
    struct Resolved {
        let kind: Kind
        let systemImage: String?
        let label: String
        let color: Color
    }

    struct ScheduleContext {
        let date: Date
        let finalClassification: AttendanceClassification
        let hasOfficePlan: Bool
        let selectedISOWeekdays: Set<Int>
        let calendar: Calendar
        let referenceDate: Date
    }

    static func recordedPresentation(
        finalClassification: AttendanceClassification,
        recordedLeave: LeaveType?,
        publicHoliday: PublicHoliday?,
        customExcludedDay: CustomExcludedDay?
    ) -> Resolved? {
        holidayPresentation(publicHoliday, finalClassification: finalClassification)
            ?? leavePresentation(recordedLeave)
            ?? exclusionPresentation(customExcludedDay)
            ?? attendancePresentation(finalClassification)
    }

    static func holidayPresentation(
        _ publicHoliday: PublicHoliday?,
        finalClassification: AttendanceClassification
    ) -> Resolved? {
        if let publicHoliday {
            return Resolved(
                kind: .publicHoliday,
                systemImage: "sparkles",
                label: "Public holiday, \(publicHoliday.name)",
                color: Color.ds.publicHoliday
            )
        }
        if finalClassification == .publicHoliday {
            return Resolved(
                kind: .publicHoliday,
                systemImage: "sparkles",
                label: "Public holiday",
                color: Color.ds.publicHoliday
            )
        }

        return nil
    }

    static func leavePresentation(_ recordedLeave: LeaveType?) -> Resolved? {
        if recordedLeave == .annualLeave {
            return Resolved(
                kind: .annualLeave,
                systemImage: "sun.max.fill",
                label: LeaveType.annualLeave.displayName,
                color: Color.ds.leaveDay
            )
        }
        if recordedLeave == .sickLeave {
            return Resolved(
                kind: .sickLeave,
                systemImage: "cross.case.fill",
                label: LeaveType.sickLeave.displayName,
                color: Color.ds.leaveDay
            )
        }

        return nil
    }

    static func exclusionPresentation(_ customExcludedDay: CustomExcludedDay?) -> Resolved? {
        guard customExcludedDay != nil else { return nil }

        return Resolved(
            kind: .excluded,
            systemImage: "calendar.badge.minus",
            label: "Custom exclusion",
            color: Color.ds.textSecondary
        )
    }

    static func attendancePresentation(_ classification: AttendanceClassification) -> Resolved? {
        switch classification {
        case .office:
            return Resolved(
                kind: .office,
                systemImage: "building.2.fill",
                label: classification.displayName,
                color: Color.ds.officeDay
            )
        case .home:
            return Resolved(
                kind: .home,
                systemImage: "house.fill",
                label: classification.displayName,
                color: Color.ds.homeDay
            )
        case .mixed:
            return Resolved(
                kind: .mixed,
                systemImage: "arrow.left.arrow.right",
                label: classification.displayName,
                color: Color.ds.info
            )
        default:
            return nil
        }
    }

    static func schedulePresentation(_ context: ScheduleContext) -> Resolved {
        let isScheduledWorkday = context.selectedISOWeekdays.contains(
            context.calendar.isoWeekday(for: context.date)
        )
            && context.finalClassification != .weekend
            && context.finalClassification != .nonWorkingDay
        if !isScheduledWorkday {
            return Resolved(
                kind: .notRequired,
                systemImage: nil,
                label: "Not a scheduled workday",
                color: Color.ds.textTertiary
            )
        }
        if context.hasOfficePlan {
            return Resolved(
                kind: .planned,
                systemImage: "calendar.badge.clock",
                label: "Planned office day",
                color: Color.ds.accentPrimary
            )
        }
        if context.calendar.startOfDay(for: context.date)
            >= context.calendar.startOfDay(for: context.referenceDate) {
            return Resolved(
                kind: .upcoming,
                systemImage: nil,
                label: "Upcoming workday",
                color: Color.ds.textTertiary
            )
        }
        return Resolved(
            kind: .review,
            systemImage: "exclamationmark",
            label: "Needs review",
            color: Color.ds.warning
        )
    }
}
