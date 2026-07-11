import Charts
import SwiftUI

struct MonthAtAGlanceSection: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let eligibleDaysToDate: Int
    let confirmedDays: Int
    let officeDays: Int
    let reviewDays: Int

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Month at a glance")
                .font(AppTypography.sectionTitle)
                .foregroundStyle(Color.ds.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("dashboard.atAGlance")

            LazyVGrid(columns: columns, spacing: AppSpacing.cardGap) {
                DSMetricTile(
                    systemImage: "calendar.badge.checkmark",
                    label: "Eligible to date",
                    value: eligibleDaysToDate.formatted(),
                    subtitle: "Through today",
                    statusColor: Color.ds.info
                )

                DSMetricTile(
                    systemImage: "checkmark.circle.fill",
                    label: "Confirmed",
                    value: confirmedDays.formatted(),
                    subtitle: "Final status recorded",
                    statusColor: confirmationColor
                )

                DSMetricTile(
                    systemImage: "building.2.fill",
                    label: "Office",
                    value: officeDays.formatted(),
                    subtitle: "Counts toward target",
                    statusColor: Color.ds.officeDay
                )

                DSMetricTile(
                    systemImage: reviewDays == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                    label: "Needs review",
                    value: reviewDays.formatted(),
                    subtitle: reviewDays == 0 ? "All caught up" : "Confirm in Calendar",
                    statusColor: reviewDays == 0 ? Color.ds.success : Color.ds.warning
                )
            }
        }
    }

    private var columns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible())]
        }

        return [
            GridItem(.flexible(), spacing: AppSpacing.cardGap),
            GridItem(.flexible())
        ]
    }

    private var confirmationColor: Color {
        guard eligibleDaysToDate > 0 else {
            return Color.ds.textSecondary
        }

        return confirmedDays == eligibleDaysToDate ? Color.ds.success : Color.ds.info
    }
}

struct RecentTrendCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let points: [ComplianceTrendPoint]
    @Binding var selectedGranularity: ComplianceTrendGranularity

    private var hasRecordedData: Bool {
        points.contains(where: \.hasRecordedData)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Recent progress")
                .font(AppTypography.sectionTitle)
                .foregroundStyle(Color.ds.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("dashboard.recentProgress")

            DSCard(includesShadow: false) {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text(trendSummary)
                        .font(AppTypography.caption)
                        .foregroundStyle(Color.ds.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    trendPicker

                    if points.isEmpty || !hasRecordedData {
                        ContentUnavailableView(
                            "No progress to chart yet",
                            systemImage: "chart.bar",
                            description: Text(
                                "Periods will appear here after you record attendance, leave, or a custom exclusion."
                            )
                        )
                        .frame(maxWidth: .infinity, minHeight: 160)
                    } else {
                        trendChart
                        legend
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var trendPicker: some View {
        if dynamicTypeSize.isAccessibilitySize {
            LabeledContent("Trend period") {
                Picker("Trend period", selection: $selectedGranularity) {
                    pickerOptions
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .accessibilityLabel("Trend period")
                .accessibilityIdentifier("dashboard.trendGranularity")
            }
            .font(AppTypography.callout)
        } else {
            Picker("Trend period", selection: $selectedGranularity) {
                pickerOptions
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("dashboard.trendGranularity")
        }
    }

    private var pickerOptions: some View {
        ForEach(ComplianceTrendGranularity.allCases) { granularity in
            Text(granularity.displayName)
                .tag(granularity)
        }
    }

    private var trendChart: some View {
        Chart(points) { point in
            if point.hasRecordedData {
                BarMark(
                    x: .value("Period", point.label),
                    y: .value("Office days", point.completedOfficeDays)
                )
                .foregroundStyle(Color.ds.accentPrimary.gradient)
                .accessibilityLabel("\(periodAccessibilityName) \(point.label)")
                .accessibilityValue(
                    "\(officeDayDescription(point.completedOfficeDays)); "
                        + "target \(officeDayDescription(point.requiredOfficeDays))"
                )
            }

            LineMark(
                x: .value("Period", point.label),
                y: .value("Target", point.requiredOfficeDays)
            )
            .foregroundStyle(Color.ds.textSecondary)
            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 4]))
            .symbol(.circle)
            .accessibilityLabel("\(periodAccessibilityName) \(point.label)")
            .accessibilityValue(
                "No recorded data; target \(officeDayDescription(point.requiredOfficeDays))"
            )
            .accessibilityHidden(point.hasRecordedData)
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisGridLine()
                    .foregroundStyle(Color.ds.separator.opacity(0.35))
                AxisValueLabel()
                    .foregroundStyle(Color.ds.textSecondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine()
                    .foregroundStyle(Color.ds.separator.opacity(0.35))
                AxisValueLabel()
                    .foregroundStyle(Color.ds.textSecondary)
            }
        }
        .frame(minHeight: 180)
    }

    private var legend: some View {
        HStack(spacing: AppSpacing.lg) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(Color.ds.accentPrimary)
                Text("Office days")
                    .foregroundStyle(Color.ds.textSecondary)
            }

            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "line.diagonal")
                Text("Target")
            }
            .foregroundStyle(Color.ds.textSecondary)
        }
        .font(AppTypography.captionStrong)
        .accessibilityHidden(true)
    }

    private var recordedPoints: [ComplianceTrendPoint] {
        points.filter(\.hasRecordedData)
    }

    private var trendSummary: String {
        guard !recordedPoints.isEmpty else {
            return "Compare office days with your saved target over time."
        }

        let targetMetCount = recordedPoints.filter {
            $0.completedOfficeDays >= $0.requiredOfficeDays
        }.count
        let periodName = periodName(count: recordedPoints.count)
        let verb = recordedPoints.count == 1 ? "is" : "are"
        return "So far, \(targetMetCount) of \(recordedPoints.count) recorded \(periodName) "
            + "\(verb) at or above target."
    }

    private func periodName(count: Int) -> String {
        switch selectedGranularity {
        case .monthly:
            count == 1 ? "month" : "months"
        case .quarterly:
            count == 1 ? "quarter" : "quarters"
        case .yearly:
            count == 1 ? "year" : "years"
        }
    }

    private var periodAccessibilityName: String {
        switch selectedGranularity {
        case .monthly:
            "Month"
        case .quarterly:
            "Quarter"
        case .yearly:
            "Year"
        }
    }

    private func officeDayDescription(_ count: Int) -> String {
        "\(count) office \(count == 1 ? "day" : "days")"
    }
}
