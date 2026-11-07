import SwiftUI

struct CalendarMonthSummary: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let monthTitle: String
    let isShowingCurrentMonth: Bool
    @Binding var displayMode: CalendarDisplayMode
    let days: [CalendarDay]
    let selectedISOWeekdays: Set<Int>
    let calendar: Calendar
    let referenceDate: Date
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void
    let onShowCurrentMonth: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            overviewHeader
            monthFacts
            displayModePicker
        }

    }

    private var overviewHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                monthIdentity
                Spacer(minLength: AppSpacing.sm)
                monthControls
            }

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                monthIdentity
                monthControls
            }
        }
    }

    private var monthIdentity: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(monthTitle)
                .font(AppTypography.title)
                .foregroundStyle(Color.ds.textPrimary)
                .contentTransition(.numericText())
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("calendar.monthOverview")
        }
    }

    private var monthControls: some View {
        GlassEffectContainer(spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.xs) {
                monthButton(
                    systemImage: "chevron.left",
                    label: "Previous month",
                    action: onPreviousMonth
                )

                Group {
                    Button("Today", action: onShowCurrentMonth)
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                        .frame(minHeight: 44)
                        .accessibilityLabel("Show current month")
                        .accessibilityIdentifier("calendar.today")
                }

                monthButton(
                    systemImage: "chevron.right",
                    label: "Next month",
                    action: onNextMonth
                )
            }
        }
    }

    private var statusSummary: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(overviewTitle)
                .font(AppTypography.title)
                .foregroundStyle(Color.ds.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(overviewMessage)
                .font(AppTypography.callout)
                .foregroundStyle(Color.ds.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var monthFacts: some View {
        Text(monthFactsText)
            .font(AppTypography.captionStrong)
            .foregroundStyle(Color.ds.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Month summary")
        .accessibilityValue(accessibilitySummary)
        .accessibilityIdentifier("calendar.monthSummary")
    }

    private var displayModePicker: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Picker("Calendar view", selection: $displayMode) {
                ForEach(CalendarDisplayMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.systemImage)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .disabled(dynamicTypeSize.isAccessibilitySize)
            .accessibilityIdentifier("calendar.displayMode")

            if dynamicTypeSize.isAccessibilitySize {
                Text("Agenda view is used with larger text.")
                    .font(AppTypography.caption)
                    .foregroundStyle(Color.ds.textSecondary)
            }
        }
    }

    private func monthButton(
        systemImage: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 30, height: 30)
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .accessibilityLabel(label)
    }

}

private extension CalendarMonthSummary {
    var reviewCount: Int {
        presentations.filter { presentation in
            if case .review = presentation.kind {
                return true
            }
            return false
        }.count
    }

    var officeCount: Int {
        days.filter { day in
            guard let date = day.date, date <= calendar.startOfDay(for: referenceDate) else {
                return false
            }

            return day.attendanceDay?.complianceTreatment == .countsAsOffice
        }.count
    }

    var recordedCount: Int {
        days.filter { day in
            guard let date = day.date, date <= calendar.startOfDay(for: referenceDate) else {
                return false
            }

            return day.attendanceDay != nil
                || day.leaveRecord != nil
                || day.publicHoliday != nil
                || day.customExcludedDay != nil
        }.count
    }

    var plannedCount: Int {
        presentations.filter { presentation in
            if case .planned = presentation.kind {
                return true
            }
            return false
        }.count
    }

    var presentations: [CalendarDayPresentation] {
        days.compactMap { day in
            guard let date = day.date else {
                return nil
            }

            return CalendarDayPresentation(
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
    }

    var overviewTitle: String {
        if reviewCount > 0 {
            return reviewCount == 1 ? "1 day to review" : "\(reviewCount) days to review"
        }

        if officeCount > 0 {
            return officeCount == 1
                ? "1 office day confirmed"
                : "\(officeCount) office days confirmed"
        }

        if recordedCount > 0 {
            return "Month records are up to date"
        }

        if plannedCount > 0 {
            return "Office days planned"
        }

        return "No attendance recorded"
    }

    var overviewMessage: String {
        if reviewCount > 0 {
            return "Add or confirm attendance for past workdays."
        }

        if plannedCount > 0 {
            let plannedLabel = plannedCount == 1
                ? "1 office day is"
                : "\(plannedCount) office days are"
            return "\(plannedLabel) planned for this month."
        }

        if recordedCount > 0 {
            return "Tap any day to review or update its status."
        }

        return "Record attendance, leave, or an office plan for this month."
    }

    var accessibilitySummary: String {
        "\(reviewCount) to review, \(officeCount) office days, \(plannedCount) planned"
    }

    var monthFactsText: String {
        "\(officeCount) office · \(plannedCount) planned · \(reviewCount) to review"
    }
}

enum CalendarDisplayMode: String, CaseIterable, Identifiable {
    case month
    case agenda

    var id: Self { self }

    var title: String {
        switch self {
        case .month:
            "Month"
        case .agenda:
            "Agenda"
        }
    }

    var systemImage: String {
        switch self {
        case .month:
            "calendar"
        case .agenda:
            "list.bullet"
        }
    }
}
