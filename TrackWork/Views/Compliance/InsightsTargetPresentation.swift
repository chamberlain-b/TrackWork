import Foundation

/// Wording and display values for the existing compliance result, without changing its rules.
struct InsightsTargetPresentation {
    enum Status: Equatable {
        case notConfigured
        case noRequiredDays
        case remaining
        case completed
        case endedShortfall
    }

    let summary: ComplianceSummary
    let targetIsConfigured: Bool
    let range: ComplianceDateRange
    let referenceDate: Date
    let calendar: Calendar

    /// Target completion is separate from the share of recorded workdays spent in the office.
    /// Keep values above 100% here; only the visual progress bar is capped.
    var completionFraction: Double? {
        guard targetIsConfigured, summary.requiredOfficeDays > 0 else { return nil }
        return Double(summary.completedOfficeDays) / Double(summary.requiredOfficeDays)
    }

    var progressFraction: Double {
        min(1, max(0, completionFraction ?? 0))
    }

    var completionText: String {
        guard let completionFraction else {
            return targetIsConfigured ? "No office days required" : "No target configured"
        }
        return "\(completionFraction.formatted(.percent.precision(.fractionLength(0)))) of target"
    }

    var officeDaysNeeded: Int { summary.officeDaysNeeded }

    /// Base eligibility already excludes public holidays. Custom exclusions are already
    /// deduplicated against leave by the calculator, so this is the effective leave impact.
    var eligibleLeaveDays: Int {
        max(0, summary.baseEligibleDays - summary.adjustedEligibleDays - summary.customExcludedDays)
    }

    var status: Status {
        guard targetIsConfigured else { return .notConfigured }
        guard summary.requiredOfficeDays > 0 else { return .noRequiredDays }
        guard officeDaysNeeded > 0 else { return .completed }
        return calendar.startOfDay(for: referenceDate) > calendar.startOfDay(for: range.end)
            ? .endedShortfall : .remaining
    }

    var statusText: String {
        let days = officeDaysNeeded == 1 ? "1 office day" : "\(officeDaysNeeded) office days"
        switch status {
        case .notConfigured:
            return "Choose an office target in Settings"
        case .noRequiredDays:
            return "No office days required for this period"
        case .remaining:
            return "\(days) still needed"
        case .completed:
            return "Target reached"
        case .endedShortfall:
            return "Period ended · \(days) short of target"
        }
    }
}
