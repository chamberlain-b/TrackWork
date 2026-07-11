import SwiftUI

struct LegendPill: View {
    let text: String
    let token: String
    let color: Color

    var body: some View {
        HStack(spacing: AppSpacing.xxs) {
            Text(token)
                .font(.caption2.weight(.bold))
                .foregroundStyle(color)
                .frame(minWidth: 24, minHeight: 20)
                .background(color.opacity(0.12), in: Capsule(style: .continuous))

            Text(text)
                .font(AppTypography.captionStrong)
                .foregroundStyle(Color.ds.textSecondary)
        }
        .padding(.horizontal, AppSpacing.xs)
        .padding(.vertical, AppSpacing.xxs)
        .background(Color.ds.surfacePrimary.opacity(0.72), in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .stroke(Color.ds.borderSubtle.opacity(0.64), lineWidth: 1)
        }
    }
}

struct CalendarDay: Identifiable {
    let id = UUID()
    let date: Date?
    let attendanceDay: AttendanceDay?
    let leaveRecord: LeaveRecord?
    let publicHoliday: PublicHoliday?
    let customExcludedDay: CustomExcludedDay?
}

struct DayCell: View {
    let date: Date
    let attendanceDay: AttendanceDay?
    let leaveRecord: LeaveRecord?
    let publicHoliday: PublicHoliday?
    let customExcludedDay: CustomExcludedDay?
    let calendar: Calendar

    private var dayNumber: Int {
        calendar.component(.day, from: date)
    }

    private var status: AttendanceClassification {
        if publicHoliday != nil {
            return .publicHoliday
        }

        if customExcludedDay != nil {
            return .nonWorkingDay
        }

        let finalClassification = attendanceDay?.finalClassification ?? .unknown
        if finalClassification == .publicHoliday {
            return attendanceDay?.detectedClassification ?? .unknown
        }

        return finalClassification
    }

    private var leaveType: LeaveType? {
        leaveRecord?.leaveType ?? status.leaveType
    }

    private var badgeText: String {
        if isFutureUnrecorded {
            return "—"
        }

        if publicHoliday != nil {
            return "PH"
        }

        if customExcludedDay != nil, leaveType == nil {
            return "EX"
        }

        return leaveType?.calendarBadgeText ?? status.calendarBadgeText
    }

    private var badgeBackgroundColor: Color {
        if isFutureUnrecorded {
            return Color.ds.surfaceSecondary.opacity(0.72)
        }

        return badgeForegroundColor.opacity(0.12)
    }

    private var badgeForegroundColor: Color {
        if isFutureUnrecorded {
            return Color.ds.textTertiary
        }

        if publicHoliday != nil {
            return Color.ds.publicHoliday
        }

        if leaveType != nil {
            return Color.ds.leaveDay
        }

        return customExcludedDay == nil ? status.calendarBadgeForegroundColor : Color.ds.textSecondary
    }

    private var cellTint: Color {
        isFutureUnrecorded ? Color.ds.borderSubtle : badgeForegroundColor
    }

    private var isToday: Bool {
        calendar.isDateInToday(date)
    }

    private var isFutureUnrecorded: Bool {
        calendar.startOfDay(for: date) > calendar.startOfDay(for: .now)
            && leaveType == nil
            && publicHoliday == nil
            && customExcludedDay == nil
            && status == .unknown
    }

    private var accessibilityStatus: String {
        if isFutureUnrecorded {
            return "Upcoming, not yet recorded"
        }

        if status == .unknown && leaveType == nil {
            if customExcludedDay != nil {
                return "Custom exclusion"
            }

            return "Needs review"
        }

        if let publicHoliday {
            return "Public holiday, \(publicHoliday.name)"
        }

        return leaveType?.displayName ?? (customExcludedDay == nil ? status.displayName : "Custom exclusion")
    }

    private var accessibilityDate: String {
        let formattedDate = date.formatted(.dateTime.day().month(.wide))
        return isToday ? "Today, \(formattedDate)" : formattedDate
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xxs) {
                Text(dayNumber, format: .number)
                    .font(AppTypography.captionStrong.monospacedDigit())
                    .foregroundStyle(isFutureUnrecorded ? Color.ds.textSecondary : Color.ds.textPrimary)

                Spacer(minLength: 0)

                if isToday {
                    Circle()
                        .fill(Color.ds.accentPrimary)
                        .frame(width: 5, height: 5)
                        .accessibilityHidden(true)
                }
            }

            Spacer(minLength: 0)

            Text(badgeText)
                .font(.caption2.weight(.bold))
                .foregroundStyle(badgeForegroundColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 22)
                .background(
                    badgeBackgroundColor,
                    in: RoundedRectangle(cornerRadius: AppRadius.xs, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.xs, style: .continuous)
                        .stroke(badgeForegroundColor.opacity(0.16), lineWidth: 1)
                }
        }
        .padding(AppSpacing.xs)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)
        .background(Color.ds.surfacePrimary.opacity(0.74))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                .stroke(
                    isToday ? Color.ds.accentPrimary.opacity(0.42) : cellTint.opacity(0.12),
                    lineWidth: isToday ? 1.5 : 1
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(accessibilityDate), \(accessibilityStatus)")
        .accessibilityIdentifier(calendar.calendarDayAccessibilityIdentifier(for: date))
    }
}
