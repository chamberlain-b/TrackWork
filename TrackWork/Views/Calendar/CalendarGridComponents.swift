import SwiftUI

struct LegendPill: View {
    let text: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 24, height: 24)
                .background(color.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

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

            if let systemImage = presentation.systemImage {
                statusMarker(systemImage: systemImage)
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

    @ViewBuilder
    private func statusMarker(systemImage: String) -> some View {
        if presentation.kind == .review, !isPrimaryReview {
            Circle()
                .fill(presentation.color)
                .frame(width: 7, height: 7)
                .frame(width: 28, height: 20)
        } else {
            Image(
                systemName: presentation.kind == .review
                    ? "exclamationmark.triangle.fill"
                    : systemImage
            )
            .font(.caption2.weight(.bold))
            .foregroundStyle(presentation.color)
            .frame(width: 28, height: 20)
            .background(
                presentation.kind == .review
                    ? Color.clear
                    : presentation.color.opacity(0.11),
                in: Capsule(style: .continuous)
            )
        }
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
