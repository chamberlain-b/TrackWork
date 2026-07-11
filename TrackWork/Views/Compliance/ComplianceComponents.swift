import SwiftUI

struct ComplianceResultsSection: View {
    let actualPercentage: Double?
    let targetValue: String
    let targetSubtitle: String
    let differenceValue: String
    let differenceSubtitle: String
    let comparisonColor: Color
    let completedOfficeDays: Int
    let eligibleWorkdays: Int
    let remainingOfficeDays: Int
    let resultText: String
    let resultStyle: DSStatusPillStyle

    private let columns = [GridItem(.adaptive(minimum: 154), spacing: AppSpacing.md)]

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

            LazyVGrid(columns: columns, spacing: AppSpacing.md) {
                officeShareTile
                requiredThresholdTile
                differenceTile
                completedOfficeDaysTile
                eligibleWorkdaysTile
                remainingOfficeDaysTile
            }
        }
    }

    private var heading: some View {
        Text("Comparison result")
            .font(AppTypography.headline)
            .foregroundStyle(Color.ds.textPrimary)
    }

    private var statusPill: some View {
        DSStatusPill(text: resultText, systemImage: "target", style: resultStyle)
    }

    private var officeShareTile: some View {
        DSMetricTile(
            systemImage: "percent",
            label: "Office share to date",
            value: actualPercentage?.formatted(.percent.precision(.fractionLength(0...1))) ?? "—",
            subtitle: "Office days / eligible days to date",
            statusColor: officeShareColor
        )
    }

    private var officeShareColor: Color {
        guard actualPercentage != nil else {
            return Color.ds.textSecondary
        }

        return resultStyle == .success ? Color.ds.success : Color.ds.warning
    }

    private var requiredThresholdTile: some View {
        DSMetricTile(
            systemImage: "target",
            label: "Saved target",
            value: targetValue,
            subtitle: targetSubtitle
        )
    }

    private var differenceTile: some View {
        DSMetricTile(
            systemImage: "plus.forwardslash.minus",
            label: "Difference",
            value: differenceValue,
            subtitle: differenceSubtitle,
            statusColor: comparisonColor
        )
    }

    private var completedOfficeDaysTile: some View {
        DSMetricTile(
            systemImage: "building.2",
            label: "Completed office days",
            value: completedOfficeDays.formatted(),
            subtitle: "Final status"
        )
    }

    private var eligibleWorkdaysTile: some View {
        DSMetricTile(
            systemImage: "calendar.badge.checkmark",
            label: "Eligible workdays",
            value: eligibleWorkdays.formatted(),
            subtitle: "Selected period after exclusions"
        )
    }

    private var remainingOfficeDaysTile: some View {
        DSMetricTile(
            systemImage: "arrow.forward.circle",
            label: "Office days still needed",
            value: remainingOfficeDays.formatted(),
            subtitle: "For the selected period",
            statusColor: remainingOfficeDays == 0 ? Color.ds.success : Color.ds.accentPrimary
        )
    }
}
