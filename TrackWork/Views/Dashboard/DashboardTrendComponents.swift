import Charts
import SwiftUI

struct RecordedCoverageCard: View {
    let eligibleDaysToDate: Int
    let confirmedDays: Int
    let officeDays: Int
    let reviewDays: Int

    var body: some View {
        DSCard(includesShadow: false) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Recorded to date")
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(Color.ds.textPrimary)

                row("Eligible days to date", value: eligibleDaysToDate)
                row("Confirmed days", value: confirmedDays)
                row("Office days", value: officeDays)

                if reviewDays > 0 {
                    row("Needs confirmation", value: reviewDays, color: Color.ds.warning)
                }
            }
        }
    }

    private func row(_ title: String, value: Int, color: Color = Color.ds.textPrimary) -> some View {
        LabeledContent {
            Text(value.formatted())
                .font(AppTypography.headline.monospacedDigit())
                .foregroundStyle(color)
        } label: {
            Text(title)
                .font(AppTypography.callout)
                .foregroundStyle(Color.ds.textSecondary)
        }
    }
}

struct RecentTrendCard: View {
    let points: [ComplianceTrendPoint]
    @Binding var selectedGranularity: ComplianceTrendGranularity

    private var hasRecordedData: Bool {
        points.contains(where: \.hasRecordedData)
    }

    var body: some View {
        DSCard(includesShadow: false) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("Recent progress")
                        .font(AppTypography.cardTitle)
                        .foregroundStyle(Color.ds.textPrimary)

                    Text("Office days compared with your saved fixed days per period or percentage target")
                        .font(AppTypography.caption)
                        .foregroundStyle(Color.ds.textSecondary)
                }

                Picker("Trend view", selection: $selectedGranularity) {
                    ForEach(ComplianceTrendGranularity.allCases) { granularity in
                        Text(granularity.displayName)
                            .tag(granularity)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("dashboard.trendGranularity")

                if points.isEmpty || !hasRecordedData {
                    ContentUnavailableView(
                        "No progress to chart yet",
                        systemImage: "chart.bar",
                        description: Text("Periods will appear here after you record attendance, leave, or a custom exclusion.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 160)
                } else {
                    trendChart
                    legend
                }
            }
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
                .accessibilityLabel(point.label)
                .accessibilityValue("\(point.completedOfficeDays) office days")
            }

            LineMark(
                x: .value("Period", point.label),
                y: .value("Target", point.requiredOfficeDays)
            )
            .foregroundStyle(Color.ds.textSecondary)
            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 4]))
            .symbol(.circle)
            .accessibilityLabel("Target")
            .accessibilityValue("\(point.requiredOfficeDays) office days")
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .frame(minHeight: 180)
    }

    private var legend: some View {
        HStack(spacing: AppSpacing.lg) {
            Label("Office days", systemImage: "chart.bar.fill")
                .foregroundStyle(Color.ds.accentPrimary)

            Label("Target", systemImage: "line.diagonal")
                .foregroundStyle(Color.ds.textSecondary)
        }
        .font(AppTypography.captionStrong)
    }
}
