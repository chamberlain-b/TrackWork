import SwiftUI

struct LegendPill: View {
    let text: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: AppSpacing.xxs) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 18, height: 18)
                .background(color.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            Text(text)
                .font(AppTypography.caption)
                .foregroundStyle(Color.ds.textSecondary)
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
    let plannedOfficeDay: PlannedOfficeDay?
}

struct DayCell: View {
    let date: Date
    let attendanceDay: AttendanceDay?
    let leaveRecord: LeaveRecord?
    let publicHoliday: PublicHoliday?
    let customExcludedDay: CustomExcludedDay?
    let plannedOfficeDay: PlannedOfficeDay?
    let selectedISOWeekdays: Set<Int>
    let calendar: Calendar
    let referenceDate: Date
    let isPrimaryReview: Bool
    var isSelected = false

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
            plannedOfficeDay: plannedOfficeDay,
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
        VStack(spacing: 2) {
            Text(dayNumber, format: .number)
                .font(AppTypography.callout.monospacedDigit())
                .foregroundStyle(isSelected ? Color.ds.backgroundPrimary : Color.ds.textPrimary)
                .frame(width: 32, height: 32)
                .background {
                    if isSelected { Circle().fill(Color.ds.interactionPrimary) }
                    else if isToday { Circle().strokeBorder(Color.ds.interactionPrimary, lineWidth: 1.5) }
                    else if !presentation.isQuiet { Circle().fill(presentation.color.opacity(0.10)) }
                }
            if let systemImage = presentation.systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(presentation.color)
                    .frame(height: 14)
                    .accessibilityHidden(true)
            } else { Color.clear.frame(height: 14) }
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDate)
        .accessibilityValue(presentation.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isSelected ? "Selected. Details are shown below." : "Shows day details")
        .accessibilityIdentifier(calendar.calendarDayAccessibilityIdentifier(for: date))
    }

}

struct CalendarAgendaRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let date: Date
    let attendanceDay: AttendanceDay?
    let leaveRecord: LeaveRecord?
    let publicHoliday: PublicHoliday?
    let customExcludedDay: CustomExcludedDay?
    let plannedOfficeDay: PlannedOfficeDay?
    let selectedISOWeekdays: Set<Int>
    let calendar: Calendar
    let referenceDate: Date
    var isSelected = false

    private var presentation: CalendarDayPresentation {
        CalendarDayPresentation(
            date: date,
            attendanceDay: attendanceDay,
            leaveRecord: leaveRecord,
            publicHoliday: publicHoliday,
            customExcludedDay: customExcludedDay,
            plannedOfficeDay: plannedOfficeDay,
            selectedISOWeekdays: selectedISOWeekdays,
            calendar: calendar,
            referenceDate: referenceDate
        )
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                        Text(date.formatted(.dateTime.weekday(.abbreviated).day()))
                            .font(AppTypography.headline)
                            .foregroundStyle(Color.ds.textPrimary)

                        Spacer(minLength: AppSpacing.sm)

                        disclosureIndicator
                    }

                    HStack(spacing: AppSpacing.sm) {
                        statusMarker

                        Text(presentation.label)
                            .font(AppTypography.body)
                            .foregroundStyle(
                                presentation.isQuiet ? Color.ds.textSecondary : Color.ds.textPrimary
                            )
                    }
                }
            } else {
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

                    statusMarker

                    Text(presentation.label)
                        .font(AppTypography.body)
                        .foregroundStyle(
                            presentation.isQuiet ? Color.ds.textSecondary : Color.ds.textPrimary
                        )

                    Spacer(minLength: AppSpacing.sm)

                    disclosureIndicator
                }
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .frame(maxWidth: .infinity, minHeight: 58)
        .background(isSelected ? Color.ds.accentSoft : Color.clear)
        .overlay(alignment: .bottom) { Divider() }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(date.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
        .accessibilityValue(presentation.label)
        .accessibilityHint(isSelected ? "Selected. Details are shown above." : "Shows day details")
        .accessibilityIdentifier(calendar.calendarDayAccessibilityIdentifier(for: date))
    }

    private var statusMarker: some View {
        Circle()
            .fill(presentation.color)
            .frame(width: 9, height: 9)
            .accessibilityHidden(true)
    }

    private var disclosureIndicator: some View {
        Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.ds.textTertiary)
            .accessibilityHidden(true)
    }
}
