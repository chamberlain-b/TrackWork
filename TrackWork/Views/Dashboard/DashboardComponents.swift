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
            "Not started"
        case .reachable:
            "On track"
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
    let businessDaysToDate: Int
    let remainingOfficeDays: Int
    let requiredOfficeDays: Int
    let reviewCount: Int
    let currentCompliance: Double?
    let status: DashboardStatus
    let targetIsConfigured: Bool

    var body: some View {
        DSProgressCard(
            sectionTitle: monthTitle,
            metricText: targetIsConfigured ? primaryMetricText : "—",
            detailText: targetIsConfigured
                ? primaryDetailText
                : "Office target not set",
            progress: currentCompliance ?? 0,
            statusText: status.title,
            statusSystemImage: status.systemImage,
            statusStyle: status.pillStyle,
            footerCaption: footerCaption,
            showsProgress: currentCompliance != nil,
            showsProgressPercentage: false,
            progressMetricTitle: currentCompliance != nil
                ? progressMetricTitle
                : nil,
            progressTint: status.color,
            progressAccessibilityLabel: reviewCount > 0
                ? "Confirmed month-to-date compliance"
                : "Month-to-date compliance",
            progressAccessibilityValue: currentCompliance != nil
                ? currentComplianceAccessibilityValue
                : nil
        )
        .accessibilityIdentifier("dashboard.hero")
    }

    private var primaryMetricText: String {
        reviewCount > 0 ? reviewCount.formatted() : remainingOfficeDays.formatted()
    }

    private var primaryDetailText: String {
        if reviewCount > 0 {
            return reviewCount == 1 ? "day needs review" : "days need review"
        }
        return remainingOfficeDaysLabel
    }

    private var progressMetricTitle: String {
        reviewCount > 0 ? "confirmed office rate" : "current compliance"
    }

    private var remainingOfficeDaysLabel: String {
        remainingOfficeDays == 1
            ? "office day still required"
            : "office days still required"
    }

    private var currentComplianceAccessibilityValue: String {
        let officeDayLabel = completedOfficeDays == 1 ? "office day" : "office days"
        let businessDayLabel = businessDaysToDate == 1
            ? "eligible business day"
            : "eligible business days"
        return "\(completedOfficeDays) \(officeDayLabel) of \(businessDaysToDate) \(businessDayLabel)"
    }

    private var footerCaption: String {
        guard targetIsConfigured else {
            return "Set an office target in Settings."
        }

        if reviewCount > 0 {
            let completedLabel = completedOfficeDays == 1
                ? "1 confirmed office day"
                : "\(completedOfficeDays) confirmed office days"
            let targetLabel = requiredOfficeDays == 1
                ? "Target: 1 day this month."
                : "Target: \(requiredOfficeDays) days this month."
            return "\(completedLabel). \(targetLabel)"
        }

        guard businessDaysToDate > 0 else {
            return "No eligible business days yet this month."
        }

        return "\(completedOfficeDays) of \(businessDaysToDate) eligible business days in office"
    }
}

struct DashboardSetupCard: View {
    let onOpenSettings: (() -> Void)?

    var body: some View {
        DSCard(includesShadow: false) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                DSIconBadge(systemImage: "slider.horizontal.3", style: .accent, size: 54)

                Text("Set your office target")
                    .font(AppTypography.title)
                    .foregroundStyle(Color.ds.textPrimary)

                Text("Choose your target, workdays and region.")
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
            title: "Record your first day",
            message: "Add office, home or leave.",
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

    var body: some View {
        DashboardCalendarAction(
            title: "\(reviewCount) day\(reviewCount == 1 ? "" : "s") to review",
            message: "Attendance is missing.",
            actionTitle: "Review",
            systemImage: "exclamationmark.triangle.fill",
            tint: Color.ds.warning,
            showsMessage: false,
            accessibilityLabel: "Review \(reviewCount) day\(reviewCount == 1 ? "" : "s") in Calendar",
            accessibilityIdentifier: "dashboard.reviewAction",
            onOpenCalendar: nil,
            destination: .reviewQueue
        )
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
    var destination: DashboardCalendarDestination = .calendar

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
                destinationView
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

    @ViewBuilder
    private var destinationView: some View {
        switch destination {
        case .calendar:
            MonthCalendarView()
        case .reviewQueue:
            ReviewQueueView()
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
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .overlay(alignment: .leading) {
            Capsule()
                .fill(tint)
                .frame(width: 3, height: 30)
                .padding(.leading, 2)
        }
    }

    private var leadingContent: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.1), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(title)
                    .font(AppTypography.callout.weight(.semibold))
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
        .foregroundStyle(tint)
    }
}

private enum DashboardCalendarDestination {
    case calendar
    case reviewQueue
}
