import Charts
import SwiftUI

struct InsightsTargetSummary: View {
    let summary: ComplianceSummary
    let presentation: InsightsTargetPresentation
    @ScaledMetric(relativeTo: .largeTitle) private var numberSize = 44.0

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Office target")
                .font(AppTypography.sectionTitle)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("\(Text(summary.completedOfficeDays.formatted()).foregroundColor(Color.ds.officeDay))\(Text(presentation.completionFraction == nil ? "" : " of \(summary.requiredOfficeDays)").foregroundColor(Color.ds.textPrimary))")
                    .font(.system(size: numberSize, weight: .bold, design: .rounded).monospacedDigit())
                    .fixedSize(horizontal: false, vertical: true)
                Text("office days recorded")
                    .font(AppTypography.callout)
                    .foregroundStyle(Color.ds.textSecondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Office target")
            .accessibilityValue(presentation.completionFraction == nil
                ? "\(summary.completedOfficeDays) office days recorded"
                : "\(summary.completedOfficeDays) of \(summary.requiredOfficeDays) office days recorded")
            .accessibilityIdentifier("insights.targetCount")

            if presentation.completionFraction != nil {
                ProgressView(value: presentation.progressFraction)
                    .tint(Color.ds.officeDay)
                    .accessibilityHidden(true)
                Text(presentation.completionText)
                    .font(AppTypography.callout.monospacedDigit())
                    .foregroundStyle(Color.ds.textSecondary)
                    .accessibilityIdentifier("insights.targetCompletion")
            }

            Label(presentation.statusText, systemImage: statusSymbol)
                .font(AppTypography.headline)
                .foregroundStyle(presentation.status == .completed ? Color.ds.success : Color.ds.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(presentation.statusText)
                .accessibilityIdentifier("insights.targetStatus")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.lg)
        .summaryCardSurface()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("insights.metrics")
    }

    private var statusSymbol: String {
        switch presentation.status {
        case .completed: "checkmark.circle.fill"
        case .endedShortfall: "calendar"
        case .notConfigured: "slider.horizontal.3"
        case .noRequiredDays: "minus.circle"
        case .remaining: "building.2"
        }
    }
}

/// Actual office attendance and each period's own requirement. The target is not a forecast.
struct InsightsOfficeTrend: View {
    let points: [AttendanceTrendPresentation]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            if let first = points.first, let last = points.last {
                Text("\(first.point.range.start.formatted(date: .abbreviated, time: .omitted)) – \(last.point.range.end.formatted(date: .abbreviated, time: .omitted))")
                    .font(AppTypography.caption)
                    .foregroundStyle(Color.ds.textSecondary)
            }
            if points.allSatisfy({ !$0.point.hasRecordedData }) {
                Label("Record attendance to start your trend.", systemImage: "chart.bar")
                    .font(AppTypography.callout)
                    .foregroundStyle(Color.ds.textSecondary)
            } else if dynamicTypeSize.isAccessibilitySize {
                ForEach(points) { item in
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text(item.point.label).font(AppTypography.headline)
                        Text("\(item.point.completedOfficeDays) office days recorded · \(item.point.requiredOfficeDays) required")
                            .font(AppTypography.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }
            } else {
                chart
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: AppSpacing.lg) { legend }
                VStack(alignment: .leading, spacing: AppSpacing.xs) { legend }
            }
            Text("Each period uses its own work policy and exclusions. Current periods are still in progress.")
                .font(AppTypography.caption)
                .foregroundStyle(Color.ds.textSecondary)
        }
        .accessibilityIdentifier("analytics.attendanceTrend")
    }

    private var chart: some View {
        Chart(points) { item in
            BarMark(x: .value("Period", item.point.label),
                    y: .value("Recorded office days", item.point.completedOfficeDays), width: .ratio(0.48))
                .foregroundStyle(Color.ds.officeDay)
                .cornerRadius(3)
                .annotation(position: .top, spacing: 4) {
                    Text(item.point.completedOfficeDays.formatted())
                        .font(AppTypography.captionStrong.monospacedDigit())
                        .foregroundStyle(Color.ds.textPrimary)
                }
                .accessibilityLabel("\(item.point.label), office days recorded")
                .accessibilityValue(item.point.completedOfficeDays.formatted())
            LineMark(x: .value("Period", item.point.label), y: .value("Required office days", item.point.requiredOfficeDays))
                .foregroundStyle(Color.ds.requiredTarget)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .symbol(.circle)
                .symbolSize(16)
                .accessibilityLabel("\(item.point.label), required office days")
                .accessibilityValue(item.point.requiredOfficeDays.formatted())
        }
        .chartLegend(.hidden)
        .chartYScale(domain: 0...chartMaximum)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) {
                AxisGridLine().foregroundStyle(Color.ds.separator.opacity(0.4))
                AxisValueLabel().foregroundStyle(Color.ds.textSecondary)
            }
        }
        .chartXAxis { AxisMarks { AxisValueLabel().foregroundStyle(Color.ds.textSecondary) } }
        .frame(height: 190)
    }

    private var chartMaximum: Double {
        Double(max(1, points.map { max($0.point.completedOfficeDays, $0.point.requiredOfficeDays) }.max() ?? 1)) * 1.18
    }

    private var legend: some View {
        Group {
            Label { Text("Office days recorded") } icon: {
                RoundedRectangle(cornerRadius: 2).fill(Color.ds.officeDay).frame(width: 10, height: 10)
            }
            Label { Text("Required").foregroundStyle(Color.ds.requiredTarget) } icon: {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 5))
                    path.addLine(to: CGPoint(x: 20, y: 5))
                }
                .stroke(Color.ds.requiredTarget, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                .frame(width: 20, height: 10)
            }
        }
        .font(AppTypography.caption)
        .foregroundStyle(Color.ds.textSecondary)
    }
}

struct InsightsEligibilitySummary: View {
    let summary: ComplianceSummary
    let eligibleLeaveDays: Int
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            row("Workdays after public holidays", value: summary.baseEligibleDays)
            row("Full-day leave", value: eligibleLeaveDays, subtracts: true)
            row("Other exclusions", value: summary.customExcludedDays, subtracts: true)
            Divider()
            row("Eligible workdays", value: summary.adjustedEligibleDays, emphasized: true)
            Text("Leave and exclusions count only when they remove an eligible workday. Overlapping days count once.")
                .font(AppTypography.caption)
                .foregroundStyle(Color.ds.textSecondary)
        }
        .accessibilityIdentifier("insights.eligibility")
    }

    private func row(_ title: String, value: Int, subtracts: Bool = false, emphasized: Bool = false) -> some View {
        let amount = subtracts && value > 0 ? "−\(value)" : value.formatted()
        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(title)
                    Text(amount).monospacedDigit()
                }
            } else {
                LabeledContent(title) { Text(amount).monospacedDigit() }
            }
        }
        .font(emphasized ? AppTypography.headline : AppTypography.callout)
        .foregroundStyle(emphasized ? Color.ds.textPrimary : Color.ds.textSecondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(amount)
    }
}
