import SwiftUI

struct CalendarMonthSummary: View {
    let days: [CalendarDay]
    let selectedISOWeekdays: Set<Int>
    let calendar: Calendar
    let referenceDate: Date

    private var reviewCount: Int {
        presentations.filter { presentation in
            if case .review = presentation.kind {
                return true
            }
            return false
        }.count
    }

    private var officeCount: Int {
        days.filter { day in
            guard let date = day.date, date <= calendar.startOfDay(for: referenceDate) else {
                return false
            }

            return day.attendanceDay?.complianceTreatment == .countsAsOffice
        }.count
    }

    private var plannedCount: Int {
        presentations.filter { presentation in
            if case .planned = presentation.kind {
                return true
            }
            return false
        }.count
    }

    private var presentations: [CalendarDayPresentation] {
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

    var body: some View {
        DSCard(includesShadow: false) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 0) {
                    metric(
                        value: reviewCount,
                        title: "To review",
                        systemImage: "exclamationmark.circle.fill",
                        color: reviewCount > 0 ? Color.ds.warning : Color.ds.textTertiary
                    )

                    Divider()

                    metric(
                        value: officeCount,
                        title: "Office days",
                        systemImage: "building.2.fill",
                        color: Color.ds.officeDay
                    )

                    Divider()

                    metric(
                        value: plannedCount,
                        title: "Planned",
                        systemImage: "calendar.badge.clock",
                        color: Color.ds.accentPrimary
                    )
                }

                VStack(spacing: AppSpacing.sm) {
                    metricRow(
                        value: reviewCount,
                        title: "To review",
                        systemImage: "exclamationmark.circle.fill",
                        color: reviewCount > 0 ? Color.ds.warning : Color.ds.textTertiary
                    )
                    metricRow(
                        value: officeCount,
                        title: "Office days",
                        systemImage: "building.2.fill",
                        color: Color.ds.officeDay
                    )
                    metricRow(
                        value: plannedCount,
                        title: "Planned",
                        systemImage: "calendar.badge.clock",
                        color: Color.ds.accentPrimary
                    )
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Month summary")
        .accessibilityValue(accessibilitySummary)
        .accessibilityIdentifier("calendar.monthSummary")
    }

    private func metric(
        value: Int,
        title: String,
        systemImage: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Label {
                Text(value.formatted())
                    .font(AppTypography.smallMetric.monospacedDigit())
                    .foregroundStyle(Color.ds.textPrimary)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(color)
            }

            Text(title)
                .font(AppTypography.caption)
                .foregroundStyle(Color.ds.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.sm)
    }

    private func metricRow(
        value: Int,
        title: String,
        systemImage: String,
        color: Color
    ) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Label(title, systemImage: systemImage)
                .foregroundStyle(color)

            Spacer(minLength: AppSpacing.sm)

            Text(value.formatted())
                .font(AppTypography.headline.monospacedDigit())
                .foregroundStyle(Color.ds.textPrimary)
        }
    }

    private var accessibilitySummary: String {
        "\(reviewCount) to review, \(officeCount) office days, \(plannedCount) planned"
    }
}
