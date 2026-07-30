import SwiftUI

extension OfficePlanView {
    var monthTitle: String {
        range.start.formatted(.dateTime.month(.wide).year())
    }

    var progressLabelText: String {
        if remainingOfficeDays == 0 {
            return "Office-day target met"
        }
        if summary.completedOfficeDays > 0 {
            let label = remainingOfficeDays == 1 ? "office day" : "office days"
            return "\(plannedCandidateDays) / \(remainingOfficeDays) remaining \(label) planned"
        }
        return "\(plannedCandidateDays) / \(summary.requiredOfficeDays) office days planned"
    }

    var progressAccessibilityValue: String {
        if remainingOfficeDays == 0 {
            return "Target met"
        }
        return "\(plannedCandidateDays) of \(remainingOfficeDays) remaining office days planned"
    }

    var planProgressValue: Double {
        guard remainingOfficeDays > 0 else {
            return 1
        }
        return Double(min(plannedCandidateDays, remainingOfficeDays))
    }

    var planProgressTotal: Double {
        Double(max(remainingOfficeDays, 1))
    }

    var additionalPlansText: String {
        if remainingOfficeDays == 0 {
            return "No more needed"
        }
        if additionalPlansNeeded == 0 {
            return "Plan ready"
        }
        return additionalPlansNeeded == 1
            ? "1 more needed"
            : "\(additionalPlansNeeded) more needed"
    }

    var planStatusText: String {
        if summary.reviewRequiredDays > 0 {
            let count = summary.reviewRequiredDays
            return count == 1 ? "Review 1 day first" : "Review \(count) days first"
        }
        if remainingOfficeDays > candidateDates.count {
            return "Target not reachable"
        }
        if remainingOfficeDays == 0 {
            return "Target already met"
        }
        if additionalPlansNeeded == 0 {
            return "Plan covers target"
        }
        return additionalPlansNeeded == 1
            ? "1 more day to cover target"
            : "\(additionalPlansNeeded) more days to cover target"
    }

    var planStatusSystemImage: String {
        if summary.reviewRequiredDays > 0 || additionalPlansNeeded > 0 {
            return "exclamationmark.circle"
        }
        return "checkmark.circle.fill"
    }

    var planStatusStyle: DSStatusPillStyle {
        if remainingOfficeDays > candidateDates.count {
            return .critical
        }
        if summary.reviewRequiredDays > 0 || additionalPlansNeeded > 0 {
            return .warning
        }
        return .success
    }

    var planAccentColor: Color {
        switch planStatusStyle {
        case .critical:
            Color.ds.critical
        case .warning:
            Color.ds.accentPrimary
        case .success:
            Color.ds.success
        case .info, .neutral:
            Color.ds.accentPrimary
        }
    }

    var suggestButtonTitle: String {
        if remainingOfficeDays == 0 {
            return "Target met"
        }
        if additionalPlansNeeded == 0 {
            return "Plan complete"
        }
        return additionalPlansNeeded == 1
            ? "Suggest 1 day"
            : "Suggest \(additionalPlansNeeded) days"
    }

    var removeUnavailablePlansTitle: String {
        invalidSelectedDates.count == 1
            ? "Remove 1 unavailable plan"
            : "Remove \(invalidSelectedDates.count) unavailable plans"
    }

    var unreachableTargetMessage: String {
        let availableDays = candidateDates.count
        let availableLabel = availableDays == 1
            ? "1 eligible workday remains"
            : "\(availableDays) eligible workdays remain"
        let targetLabel = summary.requiredOfficeDays == 1
            ? "the 1-day target"
            : "the \(summary.requiredOfficeDays)-day target"
        return "\(availableLabel), so \(targetLabel) is not reachable."
    }

    var reviewRequiredMessage: String {
        let count = summary.reviewRequiredDays
        let dayLabel = count == 1 ? "1 day still needs" : "\(count) days still need"
        return "Based on confirmed attendance. \(dayLabel) review, so this plan may change."
    }

    func dateState(for date: Date) -> OfficePlanDateState {
        let date = calendar.startOfDay(for: date)
        guard range.contains(date, calendar: calendar) else {
            return .outsideMonth
        }
        if holidayDates.contains(date) {
            return .holiday
        }
        if leaveDates.contains(date) {
            return .leave
        }
        if exclusionDates.contains(date) {
            return .excluded
        }
        if completedOfficeDates.contains(date) {
            return .completed
        }
        if validSelectedDates.contains(date) {
            return .planned
        }
        if candidateDateSet.contains(date), isPreferred(date) {
            return .preferred
        }
        if candidateDateSet.contains(date) {
            return .available
        }
        return .unavailable
    }

    func dayAction(for date: Date) -> (() -> Void)? {
        let date = calendar.startOfDay(for: date)
        guard candidateDateSet.contains(date) else {
            return nil
        }
        return {
            updatePlan(for: date, isSelected: !selectedDates.contains(date))
        }
    }

    func isInDisplayedMonth(_ date: Date) -> Bool {
        range.contains(date, calendar: calendar)
    }

    func isPreferred(_ date: Date) -> Bool {
        preferredISOWeekdays.contains(calendar.isoWeekday(for: date))
    }

    func weekPlanText(_ week: OfficePlanWeek) -> String {
        let plannedCount = validSelectedDates.intersection(Set(week.dates)).count
        let recommendedCount = recommendedCountsByWeek[week.start, default: 0]
        guard recommendedCount > 0 else {
            return plannedCount == 1 ? "1 planned" : "\(plannedCount) planned"
        }
        return "\(plannedCount) of \(recommendedCount)"
    }

    func weekRangeText(_ week: OfficePlanWeek) -> String {
        guard let end = week.dates.last else {
            return ""
        }
        let startDay = week.start.formatted(.dateTime.day())
        let endDay = end.formatted(.dateTime.day())
        let startMonth = week.start.formatted(.dateTime.month(.abbreviated)).uppercased()
        let endMonth = end.formatted(.dateTime.month(.abbreviated)).uppercased()
        if calendar.isDate(week.start, equalTo: end, toGranularity: .month) {
            return "\(startDay)–\(endDay) \(endMonth)"
        }
        return "\(startDay) \(startMonth) – \(endDay) \(endMonth)"
    }

    func weekRangeAccessibilityText(_ week: OfficePlanWeek) -> String {
        guard let end = week.dates.last else {
            return ""
        }
        return "\(week.start.formatted(.dateTime.day().month(.wide))) to \(end.formatted(.dateTime.day().month(.wide)))"
    }

    func weekIdentifier(for week: OfficePlanWeek) -> String {
        "officePlan.week.\(isoDateString(for: week.start))"
    }

    func dayIdentifier(for date: Date) -> String {
        "officePlan.day.\(isoDateString(for: date))"
    }

    func isoDateString(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    func weekStart(for date: Date) -> Date {
        let normalizedDate = calendar.startOfDay(for: date)
        return calendar.date(
            byAdding: .day,
            value: -calendar.mondayBasedWeekdayIndex(for: normalizedDate),
            to: normalizedDate
        ) ?? normalizedDate
    }
}
