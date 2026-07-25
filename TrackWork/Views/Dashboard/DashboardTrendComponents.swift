import Charts
import SwiftUI

struct UpcomingOfficePlanSection: View {
    let plannedDates: [Date]
    let displayedMonth: Date
    let referenceDate: Date

    var body: some View {
        NavigationLink {
            OfficePlanView(displayedMonth: displayedMonth, referenceDate: referenceDate)
        } label: {
            DSCard(includesShadow: false) {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    HStack {
                        Label("Office plan", systemImage: "calendar.badge.clock")
                            .font(AppTypography.cardTitle)
                            .foregroundStyle(Color.ds.textPrimary)

                        Spacer()

                        Image(systemName: "chevron.forward")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.ds.textTertiary)
                            .accessibilityHidden(true)
                    }

                    Divider()

                    HStack(alignment: .center, spacing: AppSpacing.md) {
                        Image(systemName: plannedDates.isEmpty ? "calendar.badge.plus" : "building.2.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.ds.accentPrimary)
                            .frame(width: 44, height: 44)
                            .background(Color.ds.accentPrimary.opacity(0.1), in: Circle())
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            Text(primaryText)
                                .font(AppTypography.headline)
                                .foregroundStyle(Color.ds.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(secondaryText)
                                .font(AppTypography.callout)
                                .foregroundStyle(Color.ds.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Office plan")
        .accessibilityValue("\(primaryText). \(secondaryText)")
        .accessibilityHint("Opens office-day planning")
        .accessibilityIdentifier("dashboard.officePlan")
    }

    private var primaryText: String {
        guard let nextDate = plannedDates.first else {
            return "No office days planned"
        }

        return nextDate.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    private var secondaryText: String {
        guard !plannedDates.isEmpty else {
            return "Choose dates for the rest of this month."
        }

        if plannedDates.count == 1 {
            return "Next planned office day"
        }

        return "Next of \(plannedDates.count) planned office days"
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
            Text("Trends")
                .font(AppTypography.sectionTitle)
                .foregroundStyle(Color.ds.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("compliance.trends")

            DSCard(includesShadow: false) {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text(trendSummary)
                        .font(AppTypography.caption)
                        .foregroundStyle(Color.ds.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    trendPicker

                    if points.isEmpty || !hasRecordedData {
                        ContentUnavailableView(
                            "No trend data",
                            systemImage: "chart.bar",
                            description: Text(
                                "Record attendance, leave or an exclusion to start the chart."
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
            return "Office days compared with your target."
        }

        let targetMetCount = recordedPoints.filter {
            $0.completedOfficeDays >= $0.requiredOfficeDays
        }.count
        let periodName = periodName(count: recordedPoints.count)
        let verb = recordedPoints.count == 1 ? "is" : "are"
        return "\(targetMetCount) of \(recordedPoints.count) \(periodName) \(verb) at or above target."
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
