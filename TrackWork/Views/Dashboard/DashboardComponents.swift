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
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.md) {
                    monthAndMetric
                    Spacer(minLength: AppSpacing.sm)
                    statusPill
                }

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    monthAndMetric
                    statusPill
                }
            }

            if targetIsConfigured && requiredOfficeDays > 0 {
                ProgressView(value: progress)
                    .tint(status.color)
                    .accessibilityLabel("Office-day target progress")
                    .accessibilityValue("\(completedOfficeDays) of \(requiredOfficeDays) days")

                Text(progressDetail)
                    .font(AppTypography.callout)
                    .foregroundStyle(Color.ds.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Set a requirement in Settings to calculate your monthly target.")
                    .font(AppTypography.callout)
                    .foregroundStyle(Color.ds.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private var monthAndMetric: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(monthTitle)
                .font(AppTypography.captionStrong)
                .foregroundStyle(Color.ds.textSecondary)

            Text(targetIsConfigured ? "\(completedOfficeDays) of \(requiredOfficeDays)" : "No target")
                .font(AppTypography.heroMetric.monospacedDigit())
                .foregroundStyle(Color.ds.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(targetIsConfigured ? "office days completed" : "setup required")
                .font(AppTypography.callout)
                .foregroundStyle(Color.ds.textSecondary)
        }
    }

    private var statusPill: some View {
        DSStatusPill(
            text: status.title,
            systemImage: status.systemImage,
            style: status.pillStyle
        )
    }

    private var progressDetail: String {
        let workdayLabel = availableOfficeDays == 1 ? "eligible workday" : "eligible workdays"

        if remainingOfficeDays == 0 {
            return "Monthly target met · \(availableOfficeDays) \(workdayLabel) still available"
        }

        return "\(remainingOfficeDays) more needed · \(availableOfficeDays) \(workdayLabel) available"
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

struct DashboardStartCard: View {
    let onOpenCalendar: (() -> Void)?

    var body: some View {
        DSCard(includesShadow: false) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Label("No attendance recorded this month", systemImage: "calendar.badge.plus")
                    .font(AppTypography.headline)
                    .foregroundStyle(Color.ds.textPrimary)

                Text("Confirm your first office or home day in Calendar. You can add leave there too.")
                    .font(AppTypography.body)
                    .foregroundStyle(Color.ds.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                calendarControl(title: "Open Calendar")
            }
        }
    }

    @ViewBuilder
    private func calendarControl(title: String) -> some View {
        if let onOpenCalendar {
            Button(title, systemImage: "calendar", action: onOpenCalendar)
                .buttonStyle(.borderedProminent)
        } else {
            NavigationLink {
                MonthCalendarView()
            } label: {
                Label(title, systemImage: "calendar")
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

struct DashboardReviewCard: View {
    let reviewCount: Int
    let onOpenCalendar: (() -> Void)?

    var body: some View {
        DSCard(includesShadow: false) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Label(
                    "\(reviewCount) day\(reviewCount == 1 ? "" : "s") need confirmation",
                    systemImage: "exclamationmark.triangle.fill"
                )
                    .font(AppTypography.headline)
                    .foregroundStyle(Color.ds.textPrimary)

                Text("Confirm missing or unknown attendance so this month’s status is reliable.")
                    .font(AppTypography.body)
                    .foregroundStyle(Color.ds.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                calendarControl
            }
        }
    }

    @ViewBuilder
    private var calendarControl: some View {
        if let onOpenCalendar {
            Button("Review in Calendar", systemImage: "calendar.badge.exclamationmark", action: onOpenCalendar)
                .buttonStyle(.borderedProminent)
                .tint(Color.ds.warning)
        } else {
            NavigationLink {
                MonthCalendarView()
            } label: {
                Label("Review in Calendar", systemImage: "calendar.badge.exclamationmark")
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.ds.warning)
        }
    }
}

struct MonthCalculationCard: View {
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
        DSCard(includesShadow: false) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("How this month is calculated")
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(Color.ds.textPrimary)

                metricRow("Eligible workdays", value: eligibleWorkdays.formatted(), emphasized: true)
                metricRow("Office-day target", value: requiredOfficeDays.formatted(), emphasized: true)

                DisclosureGroup("Workday adjustments") {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        metricRow("Scheduled workdays", value: scheduledWorkdays.formatted())
                        metricRow("Public holidays", value: deduction(publicHolidays))
                        metricRow("Annual leave", value: deduction(annualLeave))
                        metricRow("Sick leave", value: deduction(sickLeave))
                        metricRow("Custom exclusions", value: deduction(customExcluded))
                    }
                    .padding(.top, AppSpacing.sm)
                }
                .font(AppTypography.callout.weight(.semibold))
                .foregroundStyle(Color.ds.accentPrimary)

                DisclosureGroup("How your target is calculated") {
                    Text(explanation)
                        .font(AppTypography.callout)
                        .foregroundStyle(Color.ds.textSecondary)
                        .padding(.top, AppSpacing.xs)
                }
                .font(AppTypography.callout.weight(.semibold))
                .foregroundStyle(Color.ds.accentPrimary)

                Label(jurisdictionName, systemImage: "mappin.and.ellipse")
                    .font(AppTypography.caption)
                    .foregroundStyle(Color.ds.textSecondary)
            }
        }
    }

    private func deduction(_ value: Int) -> String {
        value == 0 ? "0" : "−\(value.formatted())"
    }

    private func metricRow(_ title: String, value: String, emphasized: Bool = false) -> some View {
        LabeledContent {
            Text(value)
                .font((emphasized ? AppTypography.headline : AppTypography.callout).monospacedDigit())
                .foregroundStyle(emphasized ? Color.ds.textPrimary : Color.ds.textSecondary)
        } label: {
            Text(title)
                .font(emphasized ? AppTypography.headline : AppTypography.callout)
                .foregroundStyle(emphasized ? Color.ds.textPrimary : Color.ds.textSecondary)
        }
    }
}
