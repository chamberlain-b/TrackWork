import Charts
import SwiftUI

struct DashboardTrendPreview: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let points: [ComplianceTrendPoint]

    private var recordedPoints: [ComplianceTrendPoint] {
        points.filter(\.hasRecordedData)
    }

    private var hasRecordedData: Bool {
        !recordedPoints.isEmpty
    }

    var body: some View {
        NavigationLink {
            ComplianceView(usesNavigationStack: false, title: "Compliance details")
        } label: {
            DSCard(includesShadow: false) {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    header

                    if hasRecordedData {
                        if dynamicTypeSize.isAccessibilitySize {
                            accessibilityTrendRows
                        } else {
                            compactChart
                            legend
                        }
                    } else {
                        emptyState
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Six-month compliance trend")
        .accessibilityValue(trendSummary)
        .accessibilityHint("Opens compliance details")
        .accessibilityIdentifier("dashboard.trends")
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("6-month trend")
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(Color.ds.textPrimary)

                Text(trendSummary)
                    .font(AppTypography.caption)
                    .foregroundStyle(Color.ds.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: AppSpacing.sm)

            Image(systemName: "chevron.forward")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.ds.textTertiary)
                .accessibilityHidden(true)
        }
    }

    private var compactChart: some View {
        Chart(points) { point in
            if point.hasRecordedData {
                BarMark(
                    x: .value("Month", point.label),
                    y: .value("Office days", point.completedOfficeDays)
                )
                .foregroundStyle(Color.ds.officeDay)
            }

            LineMark(
                x: .value("Month", point.label),
                y: .value("Target", point.requiredOfficeDays)
            )
            .foregroundStyle(Color.ds.requiredTarget)
            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            .symbol(.circle)
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.caption2)
                    .foregroundStyle(Color.ds.textSecondary)
            }
        }
        .chartYAxis(.hidden)
        .frame(height: 112)
        .accessibilityHidden(true)
    }

    private var accessibilityTrendRows: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            ForEach(Array(recordedPoints.suffix(3))) { point in
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(point.label)
                        .font(AppTypography.headline)
                        .foregroundStyle(Color.ds.textPrimary)

                    Text(trendValue(point))
                        .font(AppTypography.callout.monospacedDigit())
                        .foregroundStyle(Color.ds.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    ProgressView(
                        value: point.requiredOfficeDays > 0
                            ? min(
                                Double(point.completedOfficeDays) / Double(point.requiredOfficeDays),
                                1
                            )
                            : 0
                    )
                    .tint(Color.ds.accentPrimary)
                    .accessibilityLabel("\(point.label) target progress")
                    .accessibilityValue(trendValue(point))
                }
            }
        }
    }

    private var legend: some View {
        HStack(spacing: AppSpacing.lg) {
            Label("Office days", systemImage: "chart.bar.fill")
                .foregroundStyle(Color.ds.officeDay)

            Label("Target", systemImage: "line.diagonal")
                .foregroundStyle(Color.ds.requiredTarget)
        }
        .font(AppTypography.captionStrong)
        .accessibilityHidden(true)
    }

    private var emptyState: some View {
        Label("Record attendance to start your trend.", systemImage: "chart.bar")
            .font(AppTypography.callout)
            .foregroundStyle(Color.ds.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
    }

    private var trendSummary: String {
        guard !recordedPoints.isEmpty else {
            return "No recorded months yet"
        }

        let metTargetCount = recordedPoints.filter {
            $0.completedOfficeDays >= $0.requiredOfficeDays
        }.count
        let monthLabel = recordedPoints.count == 1 ? "month" : "months"
        return "\(metTargetCount) of \(recordedPoints.count) recorded \(monthLabel) met target"
    }

    private func trendValue(_ point: ComplianceTrendPoint) -> String {
        "\(point.completedOfficeDays) of \(point.requiredOfficeDays) office days"
    }
}
