import SwiftUI

struct LegendPill: View {
    let text: String
    let token: String
    let color: Color

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)

            Text(token)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.ds.textPrimary)
                .frame(minWidth: 20, alignment: .leading)

            Text(text)
                .font(AppTypography.caption)
                .foregroundStyle(Color.ds.textSecondary)
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(Color.ds.surfacePrimary.opacity(0.72), in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .stroke(Color.ds.borderSubtle.opacity(0.64), lineWidth: 1)
        }
    }
}

struct CalendarDay: Identifiable {
    let id: String
    let date: Date?
    let attendanceDay: AttendanceDay?
    let leaveRecord: LeaveRecord?
    let publicHoliday: PublicHoliday?
    let customExcludedDay: CustomExcludedDay?
}

struct CalendarDayPresentation {
    enum Kind {
        case office
        case home
        case mixed
        case annualLeave
        case sickLeave
        case publicHoliday
        case excluded
        case review
        case notRequired
        case upcoming
    }

    let kind: Kind
    let token: String?
    let label: String
    let color: Color

    var cellBackground: Color {
        switch kind {
        case .review:
            color.opacity(0.10)
        case .office, .home, .mixed, .annualLeave, .sickLeave, .publicHoliday, .excluded:
            color.opacity(0.055)
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
        selectedISOWeekdays: Set<Int>,
        calendar: Calendar,
        referenceDate: Date
    ) {
        let finalClassification = attendanceDay?.finalClassification ?? .unknown
        let recordedLeave = leaveRecord?.leaveType ?? finalClassification.leaveType

        if let publicHoliday {
            kind = .publicHoliday
            token = "PH"
            label = "Public holiday, \(publicHoliday.name)"
            color = Color.ds.publicHoliday
        } else if finalClassification == .publicHoliday {
            kind = .publicHoliday
            token = "PH"
            label = "Public holiday"
            color = Color.ds.publicHoliday
        } else if recordedLeave == .annualLeave {
            kind = .annualLeave
            token = "AL"
            label = LeaveType.annualLeave.displayName
            color = Color.ds.leaveDay
        } else if recordedLeave == .sickLeave {
            kind = .sickLeave
            token = "SL"
            label = LeaveType.sickLeave.displayName
            color = Color.ds.leaveDay
        } else if customExcludedDay != nil {
            kind = .excluded
            token = "EX"
            label = "Custom exclusion"
            color = Color.ds.textSecondary
        } else if finalClassification == .office {
            kind = .office
            token = "O"
            label = AttendanceClassification.office.displayName
            color = Color.ds.officeDay
        } else if finalClassification == .home {
            kind = .home
            token = "H"
            label = AttendanceClassification.home.displayName
            color = Color.ds.homeDay
        } else if finalClassification == .mixed {
            kind = .mixed
            token = "M"
            label = AttendanceClassification.mixed.displayName
            color = Color.ds.info
        } else if !selectedISOWeekdays.contains(calendar.isoWeekday(for: date))
            || finalClassification == .weekend
            || finalClassification == .nonWorkingDay {
            kind = .notRequired
            token = nil
            label = "Not a scheduled workday"
            color = Color.ds.textTertiary
        } else if calendar.startOfDay(for: date) > calendar.startOfDay(for: referenceDate) {
            kind = .upcoming
            token = nil
            label = "Upcoming workday"
            color = Color.ds.textTertiary
        } else {
            kind = .review
            token = "!"
            label = "Needs review"
            color = Color.ds.warning
        }
    }
}

struct DayCell: View {
    let date: Date
    let attendanceDay: AttendanceDay?
    let leaveRecord: LeaveRecord?
    let publicHoliday: PublicHoliday?
    let customExcludedDay: CustomExcludedDay?
    let selectedISOWeekdays: Set<Int>
    let calendar: Calendar
    let referenceDate: Date

    private var dayNumber: Int {
        calendar.component(.day, from: date)
    }

    private var presentation: CalendarDayPresentation {
        CalendarDayPresentation(
            date: date,
            attendanceDay: attendanceDay,
            leaveRecord: leaveRecord,
            publicHoliday: publicHoliday,
            customExcludedDay: customExcludedDay,
            selectedISOWeekdays: selectedISOWeekdays,
            calendar: calendar,
            referenceDate: referenceDate
        )
    }

    private var isToday: Bool {
        calendar.isDate(date, inSameDayAs: referenceDate)
    }

    private var accessibilityDate: String {
        let formattedDate = date.formatted(.dateTime.weekday(.wide).day().month(.wide).year())
        return isToday ? "Today, \(formattedDate)" : formattedDate
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(dayNumber, format: .number)
                .font(AppTypography.captionStrong.monospacedDigit())
                .foregroundStyle(isToday ? Color.white : dayNumberColor)
                .frame(width: 26, height: 26)
                .background {
                    if isToday {
                        Circle().fill(Color.ds.accentPrimary)
                    }
                }

            Spacer(minLength: 0)

            if let token = presentation.token {
                HStack(spacing: 3) {
                    Circle()
                        .fill(presentation.color)
                        .frame(width: 5, height: 5)

                    Text(token)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.ds.textPrimary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, minHeight: 18)
                .background(
                    presentation.color.opacity(0.13),
                    in: RoundedRectangle(cornerRadius: AppRadius.xs, style: .continuous)
                )
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .topLeading)
        .background(
            presentation.cellBackground,
            in: RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDate)
        .accessibilityValue(presentation.label)
        .accessibilityHint("Opens attendance details")
        .accessibilityIdentifier(calendar.calendarDayAccessibilityIdentifier(for: date))
    }

    private var dayNumberColor: Color {
        presentation.isQuiet ? Color.ds.textTertiary : Color.ds.textPrimary
    }
}

struct CalendarAgendaRow: View {
    let date: Date
    let attendanceDay: AttendanceDay?
    let leaveRecord: LeaveRecord?
    let publicHoliday: PublicHoliday?
    let customExcludedDay: CustomExcludedDay?
    let selectedISOWeekdays: Set<Int>
    let calendar: Calendar
    let referenceDate: Date

    private var presentation: CalendarDayPresentation {
        CalendarDayPresentation(
            date: date,
            attendanceDay: attendanceDay,
            leaveRecord: leaveRecord,
            publicHoliday: publicHoliday,
            customExcludedDay: customExcludedDay,
            selectedISOWeekdays: selectedISOWeekdays,
            calendar: calendar,
            referenceDate: referenceDate
        )
    }

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            VStack(spacing: 2) {
                Text(date.formatted(.dateTime.weekday(.abbreviated)))
                    .font(AppTypography.captionStrong)
                    .foregroundStyle(Color.ds.textSecondary)
                Text(date.formatted(.dateTime.day()))
                    .font(AppTypography.smallMetric.monospacedDigit())
                    .foregroundStyle(Color.ds.textPrimary)
            }
            .frame(width: 48)

            Circle()
                .fill(presentation.color)
                .frame(width: 9, height: 9)

            Text(presentation.label)
                .font(AppTypography.body)
                .foregroundStyle(presentation.isQuiet ? Color.ds.textSecondary : Color.ds.textPrimary)

            Spacer(minLength: AppSpacing.sm)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.ds.textTertiary)
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .frame(maxWidth: .infinity, minHeight: 58)
        .background(
            presentation.cellBackground,
            in: RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(date.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
        .accessibilityValue(presentation.label)
        .accessibilityHint("Opens attendance details")
        .accessibilityIdentifier(calendar.calendarDayAccessibilityIdentifier(for: date))
    }
}
