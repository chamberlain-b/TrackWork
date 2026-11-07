import SwiftUI

struct DashboardPlanConfidenceCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let confidence: OfficePlanConfidence
    let onPrimaryAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            header
            statusSummary
            metrics
            confirmedProgress

            if let completionDate = confidence.completionDate {
                detailRow(
                    title: confidence.state == .targetMet ? "Target completed" : "Completion date",
                    value: completionDate.formatted(
                        .dateTime.weekday(.wide).day().month(.wide).year()
                    ),
                    systemImage: "calendar.badge.checkmark"
                )
                .accessibilityIdentifier("dashboard.planConfidence.completionDate")
            }

            if let nextPlannedDate = confidence.nextPlannedDate {
                nextPlannedDateRow(nextPlannedDate)
            }

            Label(
                "Plans are reminders. Only confirmed attendance counts.",
                systemImage: "info.circle.fill"
            )
            .font(AppTypography.caption)
            .foregroundStyle(Color.ds.textSecondary)
            .fixedSize(horizontal: false, vertical: true)

            primaryAction
        }
        .padding(AppSpacing.md)
        .heroCardSurface()
    }
}

private extension DashboardPlanConfidenceCard {
    private var header: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    headerIcon
                    accessibilityHeaderTitle
                }
            } else {
                HStack(spacing: AppSpacing.xs) {
                    headerIcon
                    headerTitle
                }
            }
        }
        .foregroundStyle(stateColor)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Plan confidence")
        .accessibilityIdentifier("dashboard.planConfidence")
    }

    private var headerIcon: some View {
        Image(systemName: "checkmark.shield.fill")
            .font(.system(size: 18, weight: .semibold))
            .frame(width: 34, height: 34)
            .background(stateColor.opacity(0.1), in: Circle())
            .accessibilityHidden(true)
    }

    private var headerTitle: some View {
        Text("Plan confidence")
            .font(AppTypography.cardTitle)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var accessibilityHeaderTitle: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Plan")
            Text("confidence")
        }
        .font(AppTypography.cardTitle)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var statusSummary: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(statusTitle)
                .font(AppTypography.title)
                .foregroundStyle(Color.ds.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("dashboard.planConfidence.status")

            Text(statusMessage)
                .font(AppTypography.callout)
                .foregroundStyle(Color.ds.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var metrics: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    completedMetric
                    remainingMetric
                }
            } else {
                HStack(alignment: .center, spacing: AppSpacing.sm) {
                    completedMetric
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()
                        .frame(height: 58)

                    remainingMetric
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var completedMetric: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                Text(confidence.completedOfficeDays, format: .number)
                    .font(AppTypography.metric.monospacedDigit())
                    .foregroundStyle(Color.ds.interactionPrimary)

                Text("of \(confidence.requiredOfficeDays)")
                    .font(AppTypography.headline.monospacedDigit())
                    .foregroundStyle(Color.ds.textPrimary)
            }

            Text("required office days completed")
                .font(AppTypography.caption)
                .foregroundStyle(Color.ds.textSecondary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Confirmed office days")
        .accessibilityValue(
            "\(confidence.completedOfficeDays) of \(confidence.requiredOfficeDays) required"
        )
        .accessibilityIdentifier("dashboard.planConfidence.completed")
    }

    private var remainingMetric: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                Text(confidence.remainingOfficeDays, format: .number)
                    .font(AppTypography.metric.monospacedDigit())
                    .foregroundStyle(Color.ds.interactionPrimary)

                Text("still needed")
                    .font(AppTypography.headline)
                    .foregroundStyle(Color.ds.textPrimary)
            }

            Text(remainingMetricCaption)
                .font(AppTypography.caption.monospacedDigit())
                .foregroundStyle(Color.ds.textSecondary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Office days still needed")
        .accessibilityValue(confidence.remainingOfficeDays.formatted())
        .accessibilityIdentifier("dashboard.planConfidence.remaining")
    }

    private var confirmedProgress: some View {
        ProgressView(value: confidence.confirmedProgress)
            .tint(Color.ds.officeDay)
            .background(Color.ds.accentMuted.opacity(0.22), in: Capsule())
            .scaleEffect(x: 1, y: 1.55, anchor: .center)
            .accessibilityLabel("Confirmed target progress")
            .accessibilityValue(
                "\(confidence.completedOfficeDays) of \(confidence.requiredOfficeDays) office days"
            )
    }

    private func detailRow(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(stateColor)
                .frame(width: 36, height: 36)
                .background(stateColor.opacity(0.1), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(title)
                    .font(AppTypography.callout.weight(.semibold))
                    .foregroundStyle(Color.ds.textPrimary)

                Text(value)
                    .font(AppTypography.callout.monospacedDigit())
                    .foregroundStyle(Color.ds.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }

    private func nextPlannedDateRow(_ date: Date) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "calendar.badge.clock")
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.ds.interactionPrimary)
                .frame(width: 36, height: 36)
                .background(Color.ds.accentPrimary.opacity(0.1), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("Next planned office day")
                    .font(AppTypography.captionStrong)
                    .foregroundStyle(Color.ds.interactionPrimary)

                Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(AppTypography.headline)
                    .foregroundStyle(Color.ds.textPrimary)

                Text("Planned")
                    .font(AppTypography.caption)
                    .foregroundStyle(Color.ds.textSecondary)
            }
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.ds.surfaceBlueTint.opacity(0.72),
            in: RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Next planned office day")
        .accessibilityValue(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
        .accessibilityIdentifier("dashboard.planConfidence.nextDate")
    }

    private var primaryAction: some View {
        Button(action: onPrimaryAction) {
            HStack(spacing: AppSpacing.xs) {
                Text(actionTitle)
                    .font(AppTypography.headline)

                Spacer(minLength: AppSpacing.xs)

                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(Color.ds.textInverse)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 48)
            .padding(.horizontal, AppSpacing.md)
            .background(Color.ds.accentPrimary)
            .clipShape(
                RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(actionHint)
        .accessibilityIdentifier(actionIdentifier)
    }
}

private extension DashboardPlanConfidenceCard {
    private var statusTitle: String {
        switch confidence.state {
        case .targetMet:
            "Target met"
        case .covered:
            "Plan covers target"
        case .needsReview:
            "Review attendance first"
        case .shortfall(let count):
            count == 1 ? "Plan is 1 day short" : "Plan is \(count) days short"
        case .notReachable:
            "Target not reachable"
        }
    }

    private var statusMessage: String {
        switch confidence.state {
        case .targetMet:
            return "You have completed this month’s office requirement."
        case .covered:
            return "Your planned office days are enough to meet this month’s requirement."
        case .needsReview(let count):
            let dayLabel = count == 1 ? "1 past day" : "\(count) past days"
            return "Review \(dayLabel) before relying on this plan."
        case .shortfall(let count):
            let dayLabel = count == 1 ? "1 office day" : "\(count) office days"
            return "Add \(dayLabel) to cover this month’s target."
        case .notReachable:
            return "There are not enough eligible workdays left to meet this month’s target."
        }
    }

    private var remainingMetricCaption: String {
        guard let completionDate = confidence.completionDate,
              confidence.state == .covered else {
            return "this month"
        }

        return "by \(completionDate.formatted(.dateTime.day().month(.wide)))"
    }

    private var actionTitle: String {
        switch confidence.state {
        case .targetMet:
            "View plan"
        case .covered, .notReachable:
            "Review plan"
        case .needsReview:
            "Review days"
        case .shortfall:
            "Complete plan"
        }
    }

    private var actionHint: String {
        switch confidence.state {
        case .needsReview:
            "Opens days that need review"
        case .targetMet, .covered, .shortfall, .notReachable:
            "Opens office-day planning"
        }
    }

    private var actionIdentifier: String {
        switch confidence.state {
        case .needsReview:
            "dashboard.reviewAction"
        case .targetMet, .covered, .shortfall, .notReachable:
            "dashboard.officePlan"
        }
    }

    private var stateColor: Color {
        switch confidence.state {
        case .targetMet, .covered:
            Color.ds.success
        case .needsReview, .shortfall:
            Color.ds.warning
        case .notReachable:
            Color.ds.critical
        }
    }

}
