import SwiftUI

struct CalendarSelectedDayCard: View {
    let day: CalendarDay
    let selectedISOWeekdays: Set<Int>
    let calendar: Calendar
    let referenceDate: Date

    private var date: Date {
        day.date ?? referenceDate
    }

    private var presentation: CalendarDayPresentation {
        CalendarDayPresentation(
            date: date,
            attendanceDay: day.attendanceDay,
            leaveRecord: day.leaveRecord,
            publicHoliday: day.publicHoliday,
            customExcludedDay: day.customExcludedDay,
            plannedOfficeDay: day.plannedOfficeDay,
            selectedISOWeekdays: selectedISOWeekdays,
            calendar: calendar,
            referenceDate: referenceDate
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            header

            Text(contextMessage)
                .font(.caption)
                .foregroundStyle(Color.ds.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppSpacing.sm)
        .summaryCardSurface()
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: AppSpacing.md) {
                dateTitle
                Spacer(minLength: AppSpacing.sm)
                editLink
            }

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                dateTitle
                editLink
            }
        }
    }

    private var dateTitle: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(AppTypography.headline)
                .foregroundStyle(Color.ds.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("calendar.selectedDay.date")

            statusLabel

            if let attendanceSource {
                Text(attendanceSource)
                    .font(.caption)
                    .foregroundStyle(Color.ds.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("calendar.selectedDay.source")
            }
        }
    }

    private var editLink: some View {
        NavigationLink {
            DayDetailView(
                date: date,
                attendanceDay: day.attendanceDay,
                leaveRecord: day.leaveRecord,
                publicHoliday: day.publicHoliday,
                customExcludedDay: day.customExcludedDay
            )
        } label: {
            Label("Edit day", systemImage: "pencil")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.ds.interactionPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xs)
                .background(Color.ds.surfaceSecondary, in: Capsule())
                .overlay { Capsule().strokeBorder(Color.ds.borderSubtle, lineWidth: 1) }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(DSPressButtonStyle())
        .accessibilityHint("Opens the selected day’s attendance editor")
        .accessibilityIdentifier("calendar.selectedDay.edit")
    }

    private var attendanceSource: String? {
        switch presentation.kind {
        case .office, .home, .mixed:
            guard let attendance = day.attendanceDay else { return nil }
            if attendance.manualClassification != nil { return "Manually corrected" }
            if attendance.detectedClassification != .unknown { return "Detected from attendance evidence" }
            return "Recorded attendance"
        default:
            return nil
        }
    }

    private var statusLabel: some View {
        Label(
            presentation.label,
            systemImage: presentation.systemImage ?? fallbackSystemImage
        )
        .font(AppTypography.callout)
        .foregroundStyle(presentation.color)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("calendar.selectedDay.status")
    }

    private var contextMessage: String {
        if let note = day.leaveRecord?.note?.trimmingCharacters(in: .whitespacesAndNewlines),
           !note.isEmpty {
            return note
        }

        if let reason = day.customExcludedDay?.reason?.trimmingCharacters(in: .whitespacesAndNewlines),
           !reason.isEmpty {
            return reason
        }

        if let note = day.attendanceDay?.note?.trimmingCharacters(in: .whitespacesAndNewlines),
           !note.isEmpty {
            return note
        }

        switch presentation.kind {
        case .office:
            return "Confirmed office attendance counts toward this month’s target."
        case .home:
            return "Confirmed home attendance does not count toward the office target."
        case .mixed:
            return "Office time counts when it reaches your configured minimum."
        case .annualLeave, .sickLeave:
            return "Full-day leave reduces eligibility only when this is an eligible workday."
        case .publicHoliday:
            return day.publicHoliday?.name ?? "This day is excluded as a public holiday."
        case .excluded:
            return "This day is excluded from the office requirement."
        case .planned:
            return "Plans are reminders. Confirmed attendance is used for compliance."
        case .review:
            return "Attendance has not been confirmed for this past workday."
        case .notRequired:
            return "This is not one of your selected workdays."
        case .upcoming:
            return "No attendance is recorded yet."
        }
    }

    private var fallbackSystemImage: String {
        switch presentation.kind {
        case .notRequired:
            "calendar"
        case .upcoming:
            "circle.dashed"
        case .office, .home, .mixed, .annualLeave, .sickLeave, .publicHoliday,
             .excluded, .planned, .review:
            "circle.fill"
        }
    }
}
