import SwiftData
import SwiftUI

struct TodayRunwayCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var remainingNumberSize: CGFloat = 88

    let presentation: TodayDashboardPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(presentation.date.formatted(.dateTime.month(.wide))) target")
                .font(.body)
                .foregroundStyle(Color.ds.textSecondary)

            runwaySummary

            if presentation.targetIsConfigured {
                ProgressView(value: presentation.targetProgress)
                    .tint(Color.ds.accentPrimary)
                    .scaleEffect(x: 1, y: 2, anchor: .center)
                    .padding(.vertical, AppSpacing.xxs)
                    .accessibilityLabel("Monthly office target")
                    .accessibilityValue(presentation.progressDetail)
                    .accessibilityIdentifier("today.progress")
            }

            Text(presentation.progressDetail)
                .font(.body)
                .foregroundStyle(Color.ds.textSecondary)
                .contentTransition(.numericText())
                .accessibilityIdentifier("today.progressDetail")
        }
    }

    private var runwaySummary: some View {
        Group {
            if presentation.targetIsConfigured && presentation.remainingOfficeDays > 0 {
                if dynamicTypeSize >= .xxLarge {
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        remainingNumber
                        remainingCaption
                    }
                } else {
                    HStack(alignment: .center, spacing: AppSpacing.md) {
                        remainingNumber
                        remainingCaption
                    }
                }
            } else {
                Text(presentation.runwayTitle)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(presentation.targetIsConfigured ? Color.ds.success : Color.ds.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, AppSpacing.xs)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.runwayTitle)
        .accessibilityIdentifier("today.remaining")
    }

    private var remainingNumber: some View {
        Text(presentation.remainingOfficeDays, format: .number)
            .font(dynamicTypeSize >= .xxLarge
                  ? .largeTitle.weight(.bold)
                  : .system(size: remainingNumberSize, weight: .bold))
            .foregroundStyle(Color.ds.accentPrimary)
            .monospacedDigit()
            .fixedSize()
            .contentTransition(.numericText())
    }

    private var remainingCaption: some View {
        Text(presentation.remainingOfficeDays == 1 ? "office day\nto go" : "office days\nto go")
            .font(.largeTitle.weight(.bold))
            .foregroundStyle(Color.ds.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct TodayMonthlyShare: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let presentation: TodayDashboardPresentation

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    description
                    percentage
                }
            } else {
                HStack(alignment: .center, spacing: AppSpacing.md) {
                    description
                    Spacer(minLength: AppSpacing.xs)
                    percentage
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("today.monthlyShare")
    }

    private var description: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text("In office this month")
                .font(.headline)
                .foregroundStyle(Color.ds.textPrimary)
            Text(presentation.recordedWorkdayDetail)
                .font(.subheadline)
                .foregroundStyle(Color.ds.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("today.monthlyShareDetail")
        }
    }

    private var percentage: some View {
        Text(presentation.recordedWorkdayShare)
            .font(.largeTitle.weight(.bold))
            .foregroundStyle(Color.ds.accentPrimary)
            .fixedSize()
            .contentTransition(.numericText())
            .accessibilityIdentifier("today.monthlyShareValue")
    }
}

struct TodaySummaryCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let presentation: TodayDashboardPresentation
    let onCorrectToday: () -> Void
    let onSelectDay: (Date) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: AppSpacing.sm) {
                statusText
                Spacer(minLength: 0)
                if !dynamicTypeSize.isAccessibilitySize {
                    Image(systemName: presentation.status.systemImage)
                        .font(.title2)
                        .foregroundStyle(presentation.status.kind.color)
                        .accessibilityHidden(true)
                }
            }

            HStack {
                Spacer(minLength: 0)
                TodayCorrectionAction(presentation: presentation, onCorrectToday: onCorrectToday)
            }

            Divider()
            checkLocationAction
            Divider()

            TodayWeekCard(days: presentation.weekDays, onSelect: onSelectDay)
        }
        .padding(AppSpacing.sm)
        .background(
            LinearGradient(
                colors: [Color.ds.surfaceElevated, Color.ds.surfacePrimary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                .strokeBorder(Color.ds.borderSubtle.opacity(0.35), lineWidth: 0.5)
        }
    }

    private var statusText: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text("Today")
                .font(.body)
                .foregroundStyle(Color.ds.textSecondary)

            Text(presentation.status.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.ds.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if ![.notRecorded, .notRequired].contains(presentation.status.kind) {
                Text(presentation.status.source)
                    .font(.caption)
                    .foregroundStyle(Color.ds.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.status.title)
        .accessibilityValue(presentation.status.source)
        .accessibilityIdentifier("today.status")
    }

    private var checkLocationAction: some View {
        NavigationLink {
            QuickCheckInView()
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Label("Check location", systemImage: "location.fill")
                    .font(.body)
                    .foregroundStyle(Color.ds.interactionPrimary)
                Spacer(minLength: AppSpacing.xs)
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.ds.textTertiary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Uses one location sample and discards it")
        .accessibilityIdentifier("today.checkLocation")
    }
}

struct TodayWeekCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let days: [TodayWeekdayPresentation]
    let onSelect: (Date) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("This week")
                .font(.body)
                .foregroundStyle(Color.ds.textSecondary)
                .accessibilityIdentifier("today.week")

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: AppSpacing.xs) {
                    ForEach(days) { day in accessibilityDayButton(day) }
                }
            } else {
                HStack(spacing: 0) {
                    ForEach(days) { day in compactDayButton(day) }
                }
            }
        }
    }

    private func compactDayButton(_ day: TodayWeekdayPresentation) -> some View {
        Button {
            onSelect(day.date)
        } label: {
            VStack(spacing: 2) {
                Text(day.weekday)
                    .font(.caption)
                    .foregroundStyle(Color.ds.textSecondary)

                Text(day.dayNumber)
                    .font(.body)
                    .foregroundStyle(day.isToday ? Color.ds.interactionPrimary : Color.ds.textPrimary)
                    .frame(width: 32, height: 32)
                    .background(day.isToday ? Color.ds.accentSoft : Color.clear, in: Circle())

                dayIcon(day)
            }
            .frame(maxWidth: .infinity, minHeight: 72)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: day))
        .accessibilityHint("Opens this day’s attendance editor")
        .accessibilityIdentifier(dayAccessibilityIdentifier(day))
    }

    private func accessibilityDayButton(_ day: TodayWeekdayPresentation) -> some View {
        Button {
            onSelect(day.date)
        } label: {
            HStack(spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(day.date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                        .font(AppTypography.headline)
                        .foregroundStyle(Color.ds.textPrimary)
                    Text(day.statusLabel)
                        .font(AppTypography.callout)
                        .foregroundStyle(Color.ds.textSecondary)
                }
                Spacer(minLength: AppSpacing.sm)
                dayIcon(day)
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
            .background(day.isToday ? Color.ds.accentSoft : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: day))
        .accessibilityHint("Opens this day’s attendance editor")
        .accessibilityIdentifier(dayAccessibilityIdentifier(day))
    }

    private func dayIcon(_ day: TodayWeekdayPresentation) -> some View {
        Image(systemName: day.colorRole == .notRequired ? "circle" : day.systemImage ?? "circle")
            .font(.body.weight(.medium))
            .foregroundStyle(day.colorRole.color)
            .frame(width: 24, height: 24)
            .accessibilityHidden(true)
    }

    private func accessibilityLabel(for day: TodayWeekdayPresentation) -> String {
        let date = day.date.formatted(.dateTime.weekday(.wide).day().month(.wide))
        return "\(date), \(day.statusLabel)"
    }

    private func dayAccessibilityIdentifier(_ day: TodayWeekdayPresentation) -> String {
        let components = Calendar.workTrackCalendar.dateComponents([.year, .month, .day], from: day.date)
        return String(format: "today.week.%04d-%02d-%02d",
                      components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}

struct DashboardDayEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \AttendanceDay.date) private var attendanceDays: [AttendanceDay]
    @Query(sort: \LeaveRecord.date) private var leaveRecords: [LeaveRecord]
    @Query(sort: \PublicHoliday.date) private var publicHolidays: [PublicHoliday]
    @Query(sort: \CustomExcludedDay.date) private var customExcludedDays: [CustomExcludedDay]

    let date: Date

    private let calendar = Calendar.workTrackCalendar

    var body: some View {
        NavigationStack {
            DayDetailView(
                date: date,
                attendanceDay: attendanceDays.first { calendar.isDate($0.date, inSameDayAs: date) },
                leaveRecord: leaveRecords.first { calendar.isDate($0.date, inSameDayAs: date) },
                publicHoliday: publicHolidays.first { calendar.isDate($0.date, inSameDayAs: date) },
                customExcludedDay: customExcludedDays.first {
                    calendar.isDate($0.date, inSameDayAs: date)
                }
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private extension TodayStatusKind {
    var color: Color {
        switch self {
        case .office:
            Color.ds.officeDay
        case .home:
            Color.ds.homeDay
        case .mixed:
            Color.ds.info
        case .annualLeave, .sickLeave:
            Color.ds.leaveDay
        case .publicHoliday:
            Color.ds.publicHoliday
        case .planned:
            Color.ds.accentPrimary
        case .needsReview:
            Color.ds.warning
        case .excluded, .notRequired, .notRecorded:
            Color.ds.textTertiary
        }
    }

}
