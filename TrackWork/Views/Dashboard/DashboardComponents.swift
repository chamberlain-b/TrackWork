import SwiftUI

enum DashboardStatus {
    case notConfigured
    case noEligibleDays
    case ready
    case reachable
    case needsReview
    case complete
    case notReachable

    var title: String {
        switch self {
        case .notConfigured:
            "No target"
        case .noEligibleDays:
            "No eligible days"
        case .ready:
            "Ready to begin"
        case .reachable:
            "Target reachable"
        case .needsReview:
            "Needs review"
        case .complete:
            "Target met"
        case .notReachable:
            "Target not reachable"
        }
    }

    var systemImage: String {
        switch self {
        case .notConfigured:
            "target"
        case .noEligibleDays:
            "calendar"
        case .ready:
            "calendar.badge.plus"
        case .reachable:
            "arrow.up.right.circle.fill"
        case .needsReview:
            "exclamationmark.triangle.fill"
        case .complete:
            "checkmark.circle.fill"
        case .notReachable:
            "xmark.octagon.fill"
        }
    }

    var color: Color {
        switch self {
        case .notConfigured, .noEligibleDays:
            Color.ds.textSecondary
        case .ready, .reachable:
            Color.ds.accentPrimary
        case .needsReview:
            Color.ds.warning
        case .complete:
            Color.ds.success
        case .notReachable:
            Color.ds.critical
        }
    }

    var pillStyle: DSStatusPillStyle {
        switch self {
        case .notConfigured, .noEligibleDays:
            .neutral
        case .ready, .reachable:
            .info
        case .needsReview:
            .warning
        case .complete:
            .success
        case .notReachable:
            .critical
        }
    }
}

struct ComplianceHeroCard: View {
    let monthTitle: String
    let completedOfficeDays: Int
    let requiredOfficeDays: Int
    let remainingOfficeDays: Int
    let availableOfficeDays: Int
    let progress: Double
    let status: DashboardStatus
    let targetIsConfigured: Bool

    var body: some View {
        DSProgressCard(
            sectionTitle: monthTitle,
            metricText: targetIsConfigured ? "\(completedOfficeDays) of \(requiredOfficeDays)" : "No target",
            detailText: targetIsConfigured
                ? "\(requiredOfficeDays) office days required this month"
                : "Setup required",
            progress: progress,
            statusText: status.title,
            statusSystemImage: status.systemImage,
            statusStyle: status.pillStyle,
            footerCaption: footerCaption,
            showsProgress: targetIsConfigured && requiredOfficeDays > 0,
            progressTint: status.color,
            progressAccessibilityLabel: "Office-day target progress",
            progressAccessibilityValue: targetIsConfigured
                ? "\(completedOfficeDays) of \(requiredOfficeDays) office days"
                : nil
        )
        .accessibilityIdentifier("dashboard.hero")
    }

    private var progressDetail: String {
        let workdayLabel = availableOfficeDays == 1 ? "eligible workday" : "eligible workdays"

        switch status {
        case .noEligibleDays:
            return "No eligible workdays this month after holidays, leave, and exclusions."
        case .complete:
            return "Monthly target met · \(availableOfficeDays) \(workdayLabel) still available"
        default:
            return "\(remainingOfficeDays) more needed · \(availableOfficeDays) \(workdayLabel) available"
        }
    }

    private var footerCaption: String {
        if targetIsConfigured {
            return progressDetail
        }

        return "Set a requirement in Settings to calculate your monthly target."
    }
}

struct DashboardSetupCard: View {
    let onOpenSettings: (() -> Void)?

    var body: some View {
        DSCard(includesShadow: false) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                DSIconBadge(systemImage: "slider.horizontal.3", style: .accent, size: 54)

                Text("Set up your work rule")
                    .font(AppTypography.title)
                    .foregroundStyle(Color.ds.textPrimary)

                Text("Choose your region, workdays, and office target to start.")
                    .font(AppTypography.body)
                    .foregroundStyle(Color.ds.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                settingsControl
            }
        }
    }

    @ViewBuilder
    private var settingsControl: some View {
        if let onOpenSettings {
            Button("Open Settings", systemImage: "gearshape", action: onOpenSettings)
                .buttonStyle(.borderedProminent)
        } else {
            NavigationLink {
                SettingsView()
            } label: {
                Label("Open Settings", systemImage: "gearshape")
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

struct DashboardStartAction: View {
    let onOpenCalendar: (() -> Void)?

    var body: some View {
        DashboardCalendarAction(
            title: "No attendance recorded this month",
            message: "Confirm your first office or home day. You can add leave there too.",
            actionTitle: "Open Calendar",
            systemImage: "calendar.badge.plus",
            tint: Color.ds.accentPrimary,
            showsMessage: true,
            accessibilityLabel: "Open Calendar to record attendance",
            accessibilityIdentifier: "dashboard.calendarAction",
            onOpenCalendar: onOpenCalendar
        )
    }
}

struct DashboardReviewAction: View {
    let reviewCount: Int
    let onOpenCalendar: (() -> Void)?

    var body: some View {
        DashboardCalendarAction(
            title: "\(reviewCount) day\(reviewCount == 1 ? "" : "s") need confirmation",
            message: "Confirm missing attendance so this month’s status is reliable.",
            actionTitle: "Review",
            systemImage: "exclamationmark.triangle.fill",
            tint: Color.ds.warning,
            showsMessage: false,
            accessibilityLabel: "Review \(reviewCount) day\(reviewCount == 1 ? "" : "s") in Calendar",
            accessibilityIdentifier: "dashboard.calendarAction",
            onOpenCalendar: onOpenCalendar
        )
    }
}

struct MonthCalculationCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let scheduledWorkdays: Int
    let publicHolidays: Int
    let annualLeave: Int
    let sickLeave: Int
    let customExcluded: Int
    let eligibleWorkdays: Int
    let requiredOfficeDays: Int
    let jurisdictionName: String
    let explanation: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Calculation details")
                .font(AppTypography.sectionTitle)
                .foregroundStyle(Color.ds.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("dashboard.calculation")

            DSCard(includesShadow: false) {
                DisclosureGroup {
                    calculationBreakdown
                        .padding(.top, AppSpacing.sm)
                } label: {
                    Text("\(eligibleWorkdays) eligible workdays → \(requiredOfficeDays) required")
                        .font(AppTypography.headline.monospacedDigit())
                        .foregroundStyle(Color.ds.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(
                            "\(eligibleWorkdays) eligible workdays, \(requiredOfficeDays) office days required"
                        )
                }
                .tint(Color.ds.accentPrimary)
                .accessibilityIdentifier("dashboard.calculation.disclosure")
            }
        }
    }

    private var calculationBreakdown: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Divider()

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                metricRow("Scheduled workdays", value: scheduledWorkdays.formatted())
                metricRow("Public holidays", value: deduction(publicHolidays))
                metricRow("Annual leave", value: deduction(annualLeave))
                metricRow("Sick leave", value: deduction(sickLeave))
                metricRow("Custom exclusions", value: deduction(customExcluded))
            }

            Divider()

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Target rule")
                    .font(AppTypography.captionStrong)
                    .foregroundStyle(Color.ds.textPrimary)

                Text(explanation)
                    .font(AppTypography.callout)
                    .foregroundStyle(Color.ds.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Label(jurisdictionName, systemImage: "mappin.and.ellipse")
                .font(AppTypography.caption)
                .foregroundStyle(Color.ds.textSecondary)
        }
    }

    private func deduction(_ value: Int) -> String {
        value == 0 ? "0" : "−\(value.formatted())"
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

private struct DashboardCalendarAction: View {
    let title: String
    let message: String
    let actionTitle: String
    let systemImage: String
    let tint: Color
    let showsMessage: Bool
    let accessibilityLabel: String
    let accessibilityIdentifier: String
    let onOpenCalendar: (() -> Void)?

    var body: some View {
        control
    }

    @ViewBuilder
    private var control: some View {
        if let onOpenCalendar {
            Button(action: onOpenCalendar) {
                label
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(message)
            .accessibilityHint("Opens Calendar")
            .accessibilityIdentifier(accessibilityIdentifier)
        } else {
            NavigationLink {
                MonthCalendarView()
            } label: {
                label
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(message)
            .accessibilityHint("Opens Calendar")
            .accessibilityIdentifier(accessibilityIdentifier)
        }
    }

    private var label: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: AppSpacing.sm) {
                leadingContent
                Spacer(minLength: AppSpacing.xs)
                actionLabel
            }

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                leadingContent
                actionLabel
                    .padding(.leading, 42)
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .glassSurface(cornerRadius: AppRadius.lg, tint: tint, isInteractive: true)
    }

    private var leadingContent: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.1), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(title)
                    .font(AppTypography.headline)
                    .foregroundStyle(Color.ds.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if showsMessage {
                    Text(message)
                        .font(AppTypography.callout)
                        .foregroundStyle(Color.ds.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var actionLabel: some View {
        HStack(spacing: AppSpacing.xxs) {
            Text(actionTitle)
            Image(systemName: "chevron.right")
                .accessibilityHidden(true)
        }
        .font(AppTypography.captionStrong)
        .foregroundStyle(Color.ds.textPrimary)
    }
}
