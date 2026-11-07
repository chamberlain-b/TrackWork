import SwiftUI

struct ComplianceResultsSection: View {
    let actualPercentage: Double?
    let targetValue: String
    let targetSubtitle: String
    let targetPercentage: Double?
    let isPercentageTarget: Bool
    let targetMet: Bool?
    let completedOfficeDays: Int
    let eligibleWorkdays: Int
    let eligibleDaysToDate: Int
    let remainingOfficeDays: Int
    let resultText: String
    let resultStyle: DSStatusPillStyle

    private let columns = [GridItem(.adaptive(minimum: 94), spacing: AppSpacing.md)]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    heading
                    Spacer()
                    statusPill
                }

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    heading
                    statusPill
                }
            }

            DSCard(includesShadow: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    HStack(alignment: .center, spacing: AppSpacing.md) {
                        Image(systemName: primarySystemImage)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(primaryColor)
                            .frame(width: 44, height: 44)
                            .background(primaryColor.opacity(0.1), in: Circle())
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            Text(primaryValue)
                                .font(AppTypography.heroMetric.monospacedDigit())
                                .foregroundStyle(Color.ds.accentPrimary)

                            Text(primaryLabel)
                                .font(AppTypography.callout)
                                .foregroundStyle(Color.ds.textSecondary)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(primaryLabel)
                    .accessibilityValue(primaryValue)

                    Divider()

                    LazyVGrid(columns: columns, alignment: .leading, spacing: AppSpacing.lg) {
                        compactMetric(
                            label: "Office",
                            value: completedOfficeDays.formatted(),
                            subtitle: "Recorded"
                        )
                        compactMetric(
                            label: "Target",
                            value: targetValue,
                            subtitle: targetSubtitle
                        )
                        compactMetric(
                            label: "Eligible",
                            value: eligibleWorkdays.formatted(),
                            subtitle: "In period"
                        )

                        if isPercentageTarget {
                            compactMetric(
                                label: "Gap",
                                value: percentageGap?.formatted(
                                    .percent.precision(.fractionLength(0...1))
                                ) ?? "—",
                                subtitle: targetMet == true ? "Target met" : "To target"
                            )
                        }
                    }
                }
            }
        }
    }

    private var heading: some View {
        Text("Result")
            .font(AppTypography.headline)
            .foregroundStyle(Color.ds.textPrimary)
    }

    private var statusPill: some View {
        DSStatusPill(text: resultText, systemImage: "target", style: resultStyle)
    }

    private var primarySystemImage: String {
        if isPercentageTarget {
            return "percent"
        }

        return remainingOfficeDays == 0 ? "checkmark.circle.fill" : "arrow.forward.circle.fill"
    }

    private var primaryColor: Color {
        guard targetMet != true else {
            return Color.ds.success
        }
        guard actualPercentage != nil || !isPercentageTarget else {
            return Color.ds.textSecondary
        }

        return Color.ds.accentPrimary
    }

    private var primaryValue: String {
        if isPercentageTarget {
            return actualPercentage?.formatted(.percent.precision(.fractionLength(0...1))) ?? "—"
        }

        return remainingOfficeDays.formatted()
    }

    private var primaryLabel: String {
        if isPercentageTarget {
            return eligibleDaysToDate > 0 ? "Office rate to date" : "No eligible days yet"
        }
        if remainingOfficeDays == 0 {
            return "Office target met"
        }

        return remainingOfficeDays == 1
            ? "Office day needed for target"
            : "Office days needed for target"
    }

    private var percentageGap: Double? {
        guard let actualPercentage, let targetPercentage else {
            return nil
        }

        return max(0, targetPercentage - actualPercentage)
    }

    private func compactMetric(label: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(label)
                .font(AppTypography.captionStrong)
                .foregroundStyle(Color.ds.textSecondary)

            Text(value)
                .font(AppTypography.smallMetric.monospacedDigit())
                .foregroundStyle(Color.ds.accentPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(AppTypography.caption)
                .foregroundStyle(Color.ds.textTertiary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(value), \(subtitle)")
    }
}

struct ComplianceCalculationDisclosure: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let startingEligibleWorkdays: Int
    let excludedWorkdays: Int
    let eligibleWorkdays: Int
    let requiredOfficeDays: Int
    let jurisdictionName: String
    let explanation: String

    var body: some View {
        DSCard(includesShadow: false) {
            DisclosureGroup {
                calculationDetails
                    .padding(.top, AppSpacing.sm)
            } label: {
                Label("Calculation details", systemImage: "info.circle")
                    .font(AppTypography.headline)
                    .foregroundStyle(Color.ds.textPrimary)
            }
            .tint(Color.ds.accentPrimary)
            .accessibilityIdentifier("compliance.calculation.disclosure")
        }
    }

    private var calculationDetails: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Divider()

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                if excludedWorkdays > 0 {
                    metricRow("Starting eligible workdays", value: startingEligibleWorkdays.formatted())
                    metricRow("Leave and exclusions", value: "−\(excludedWorkdays.formatted())")
                }
                metricRow("Eligible workdays", value: eligibleWorkdays.formatted())
                metricRow("Required office days", value: requiredOfficeDays.formatted())
            }

            Divider()

            Text(explanation)
                .font(AppTypography.callout)
                .foregroundStyle(Color.ds.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Label(jurisdictionName, systemImage: "mappin.and.ellipse")
                .font(AppTypography.caption)
                .foregroundStyle(Color.ds.textSecondary)
        }
    }

    @ViewBuilder
    private func metricRow(_ title: String, value: String) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(title)
                        .font(AppTypography.callout)
                        .foregroundStyle(Color.ds.textSecondary)

                    Text(value)
                        .font(AppTypography.headline.monospacedDigit())
                        .foregroundStyle(Color.ds.textPrimary)
                }
            } else {
                LabeledContent {
                    Text(value)
                        .font(AppTypography.callout.monospacedDigit())
                        .foregroundStyle(Color.ds.textSecondary)
                } label: {
                    Text(title)
                        .font(AppTypography.callout)
                        .foregroundStyle(Color.ds.textSecondary)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}
