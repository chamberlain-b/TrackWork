import Charts
import SwiftUI

struct DSMetricStrip: View {
    struct Metric: Identifiable {
        var id: String { label }
        let label: String
        let value: String
        var detail: String? = nil
    }
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let metrics: [Metric]

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppSpacing.md) { metricContents }
            } else {
                HStack(alignment: .top, spacing: AppSpacing.md) { metricContents }
            }
        }
        .padding(.vertical, AppSpacing.sm)
    }

    private var metricContents: some View {
        ForEach(metrics) { metric in
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(metric.value)
                    .font(AppTypography.metric.monospacedDigit())
                    .foregroundStyle(Color.ds.accentPrimary)
                Text(metric.label)
                    .font(AppTypography.caption)
                    .foregroundStyle(Color.ds.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail = metric.detail {
                    Text(detail)
                        .font(AppTypography.caption)
                        .foregroundStyle(Color.ds.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(metric.label)
            .accessibilityValue([metric.value, metric.detail].compactMap { $0 }.joined(separator: ", "))
            if metric.id != metrics.last?.id {
                if dynamicTypeSize.isAccessibilitySize { Divider() } else { Divider().frame(height: 54) }
            }
        }
    }
}

struct DSAnalyticsRing: View {
    let fraction: Double
    let value: String
    let caption: String
    var remainder: Color = Color.ds.accentMuted.opacity(0.3)

    var body: some View {
        ZStack {
            Circle().stroke(remainder, lineWidth: 12)
            Circle()
                .trim(from: 0, to: min(max(fraction, 0), 1))
                .stroke(Color.ds.officeDay, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: AppSpacing.xxs) {
                Text(value).font(AppTypography.heroMetric.monospacedDigit())
                    .foregroundStyle(Color.ds.officeDay)
                Text(caption).font(AppTypography.caption)
                    .foregroundStyle(Color.ds.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(AppSpacing.md)
        }
        .frame(width: 150, height: 150)
        .padding(6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(caption)
        .accessibilityValue(value)
    }
}

struct DSComplianceProgress: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let summary: ComplianceSummary
    let targetIsConfigured: Bool

    private var fraction: Double {
        summary.requiredOfficeDays > 0 ? Double(summary.completedOfficeDays) / Double(summary.requiredOfficeDays) : 0
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("\(summary.completedOfficeDays) of \(summary.requiredOfficeDays) office days")
                        .font(AppTypography.metric.monospacedDigit())
                        .foregroundStyle(Color.ds.officeDay)
                    remaining
                    ProgressView(value: min(max(fraction, 0), 1)).tint(Color.ds.officeDay)
                }
            } else {
                HStack(spacing: AppSpacing.xl) {
                    DSAnalyticsRing(fraction: fraction, value: summary.completedOfficeDays.formatted(),
                                    caption: "of \(summary.requiredOfficeDays) office days")
                    remaining
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, AppSpacing.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Office target progress")
        .accessibilityValue(targetIsConfigured
            ? "\(summary.completedOfficeDays) of \(summary.requiredOfficeDays) required office days completed. \(summary.officeDaysNeeded) office \(summary.officeDaysNeeded == 1 ? "day" : "days") still needed."
            : "No office target configured")
        .accessibilityIdentifier("home.targetProgress")
    }

    private var remaining: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(targetIsConfigured ? summary.officeDaysNeeded.formatted() : "—")
                .font(AppTypography.heroMetric.monospacedDigit())
                .foregroundStyle(targetIsConfigured ? Color.ds.accentPrimary : Color.ds.textSecondary)
            Text(targetIsConfigured ? "office days still needed" : "Set your work policy in Settings")
                .font(AppTypography.callout)
                .foregroundStyle(Color.ds.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct DSAttendanceMix: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let mix: AttendanceMix
    var usesDonut = false
    var showsExplanation = true

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            if let share = mix.officeShare {
                if usesDonut && !dynamicTypeSize.isAccessibilitySize {
                    HStack(spacing: AppSpacing.xl) {
                        DSAnalyticsRing(fraction: share,
                                        value: share.formatted(.percent.precision(.fractionLength(0))),
                                        caption: "Office\nof \(mix.totalDays) recorded days", remainder: Color.ds.homeDay)
                        values
                    }
                } else {
                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            Color.ds.officeDay.frame(width: geometry.size.width * share)
                            Color.ds.homeDay
                        }
                    }
                    .frame(height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                    .accessibilityHidden(true)
                    if dynamicTypeSize.isAccessibilitySize { values }
                    else {
                        HStack(alignment: .top) {
                            compactValue("Office", symbol: "building.2.fill", days: mix.officeDays, share: mix.officeShare)
                            Spacer()
                            compactValue("Home", symbol: "house.fill", days: mix.homeDays, share: mix.homeShare)
                        }
                    }
                }
                Text(showsExplanation
                     ? "Based on \(mix.totalDays) eligible recorded days; unrecorded days are not included. Mixed days use your office-time threshold."
                     : "Based on \(mix.totalDays) eligible recorded days; unrecorded days are not included.")
                    .font(AppTypography.caption)
                    .foregroundStyle(Color.ds.textSecondary)
            } else {
                Label("No eligible recorded days in this period.", systemImage: "building.2.crop.circle")
                    .font(AppTypography.callout)
                    .foregroundStyle(Color.ds.textSecondary)
            }
        }
        .accessibilityIdentifier("analytics.workMix")
    }

    private func compactValue(_ title: String, symbol: String, days: Int, share: Double?) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Label(title, systemImage: symbol).font(AppTypography.caption)
            Text("\(share?.formatted(.percent.precision(.fractionLength(0))) ?? "—") · \(days) of \(mix.totalDays) days")
                .font(AppTypography.callout.monospacedDigit())
        }
        .foregroundStyle(Color.ds.textPrimary)
        .accessibilityElement(children: .combine)
    }

    private var values: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            mixValue("Office", systemImage: "building.2.fill", days: mix.officeDays, share: mix.officeShare)
            mixValue("Home", systemImage: "house.fill", days: mix.homeDays, share: mix.homeShare)
        }
    }

    private func mixValue(_ label: String, systemImage: String, days: Int, share: Double?) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Label(label, systemImage: systemImage)
            Text("\(share?.formatted(.percent.precision(.fractionLength(0))) ?? "—") · \(days) of \(mix.totalDays) days")
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(AppTypography.callout)
        .foregroundStyle(Color.ds.textPrimary)
        .accessibilityElement(children: .combine)
    }
}

struct DSAttendanceTrend: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let points: [AttendanceTrendPresentation]
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            if let first = points.first, let last = points.last {
                Text("\(first.point.range.start.formatted(date: .abbreviated, time: .omitted)) – \(last.point.range.end.formatted(date: .abbreviated, time: .omitted))")
                    .font(AppTypography.caption)
                    .foregroundStyle(Color.ds.textSecondary)
            }
            if points.allSatisfy({ !$0.point.hasRecordedData }) {
                Label("Record attendance to start your trend.", systemImage: "chart.bar")
                    .font(AppTypography.callout).foregroundStyle(Color.ds.textSecondary)
            } else if dynamicTypeSize.isAccessibilitySize {
                ForEach(compact ? Array(points.filter { $0.point.hasRecordedData }.suffix(3)) : points) { item in
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text(item.point.label).font(AppTypography.headline)
                        Text("Office \(item.mix.officeDays), home \(item.mix.homeDays), target \(item.point.requiredOfficeDays)")
                            .font(AppTypography.callout)
                    }
                    .accessibilityElement(children: .combine)
                }
            } else {
                chart
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: AppSpacing.md) { legend }
                VStack(alignment: .leading, spacing: AppSpacing.xs) { legend }
            }
        }
        .accessibilityIdentifier("analytics.attendanceTrend")
    }

    private var chart: some View {
        Chart(points) { item in
            BarMark(x: .value("Period", item.point.label), y: .value("Days", item.mix.officeDays))
                .position(by: .value("Location", "Office"))
                .foregroundStyle(Color.ds.officeDay)
                .accessibilityLabel("\(item.point.label), office")
                .accessibilityValue("\(item.mix.officeDays) days")
            BarMark(x: .value("Period", item.point.label), y: .value("Days", item.mix.homeDays))
                .position(by: .value("Location", "Home"))
                .foregroundStyle(Color.ds.homeDay)
                .accessibilityLabel("\(item.point.label), home")
                .accessibilityValue("\(item.mix.homeDays) days")
            LineMark(x: .value("Period", item.point.label), y: .value("Target", item.point.requiredOfficeDays))
                .foregroundStyle(Color.ds.requiredTarget)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .accessibilityLabel("\(item.point.label), required office days")
                .accessibilityValue(item.point.requiredOfficeDays.formatted())
        }
        .chartLegend(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) {
                AxisGridLine().foregroundStyle(Color.ds.separator.opacity(0.4))
                AxisValueLabel().foregroundStyle(Color.ds.textSecondary)
            }
        }
        .chartXAxis {
            AxisMarks { AxisValueLabel().foregroundStyle(Color.ds.textSecondary) }
        }
        .frame(height: compact ? 150 : 230)
    }

    private var legend: some View {
        Group {
            Label("Office", systemImage: "building.2.fill")
                .foregroundStyle(Color.ds.officeDay)
            Label("Home", systemImage: "house.fill")
                .foregroundStyle(Color.ds.homeDay)
            Label("Target", systemImage: "line.diagonal")
                .foregroundStyle(Color.ds.requiredTarget)
        }
        .font(AppTypography.caption)
        .foregroundStyle(Color.ds.textSecondary)
    }
}
