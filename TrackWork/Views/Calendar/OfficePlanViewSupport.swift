import SwiftUI

extension OfficePlanView {
    func monthTitle(_ data: OfficePlanViewDataSnapshot) -> String {
        data.range.start.formatted(.dateTime.month(.wide).year())
    }

    var monthTitle: String {
        monthTitle(planData)
    }

    func progressLabelText(_ data: OfficePlanViewDataSnapshot) -> String {
        if data.remainingOfficeDays == 0 {
            return "Office-day target met"
        }
        if data.summary.completedOfficeDays > 0 {
            let label = data.remainingOfficeDays == 1 ? "office day" : "office days"
            return "\(data.plannedCandidateDays) / \(data.remainingOfficeDays) remaining \(label) planned"
        }
        return "\(data.plannedCandidateDays) / \(data.summary.requiredOfficeDays) office days planned"
    }

    var progressLabelText: String {
        progressLabelText(planData)
    }

    func progressAccessibilityValue(_ data: OfficePlanViewDataSnapshot) -> String {
        if data.remainingOfficeDays == 0 {
            return "Target met"
        }
        return "\(data.plannedCandidateDays) of \(data.remainingOfficeDays) remaining office days planned"
    }

    var progressAccessibilityValue: String {
        progressAccessibilityValue(planData)
    }

    func planProgressValue(_ data: OfficePlanViewDataSnapshot) -> Double {
        guard data.remainingOfficeDays > 0 else {
            return 1
        }
        return Double(min(data.plannedCandidateDays, data.remainingOfficeDays))
    }

    var planProgressValue: Double {
        planProgressValue(planData)
    }

    func planProgressTotal(_ data: OfficePlanViewDataSnapshot) -> Double {
        Double(max(data.remainingOfficeDays, 1))
    }

    var planProgressTotal: Double {
        planProgressTotal(planData)
    }

    func additionalPlansText(_ data: OfficePlanViewDataSnapshot) -> String {
        if data.remainingOfficeDays == 0 {
            return "No more needed"
        }
        if data.additionalPlansNeeded == 0 {
            return "Plan ready"
        }
        return data.additionalPlansNeeded == 1
            ? "1 more needed"
            : "\(data.additionalPlansNeeded) more needed"
    }

    var additionalPlansText: String {
        additionalPlansText(planData)
    }

    func planStatusText(_ data: OfficePlanViewDataSnapshot) -> String {
        if data.summary.reviewRequiredDays > 0 {
            let count = data.summary.reviewRequiredDays
            return count == 1 ? "Review 1 day first" : "Review \(count) days first"
        }
        if data.remainingOfficeDays > data.candidateDates.count {
            return "Target not reachable"
        }
        if data.remainingOfficeDays == 0 {
            return "Target already met"
        }
        if data.additionalPlansNeeded == 0 {
            return "Plan covers target"
        }
        return data.additionalPlansNeeded == 1
            ? "1 more day to cover target"
            : "\(data.additionalPlansNeeded) more days to cover target"
    }

    var planStatusText: String {
        planStatusText(planData)
    }

    func planStatusSystemImage(_ data: OfficePlanViewDataSnapshot) -> String {
        if data.summary.reviewRequiredDays > 0 || data.additionalPlansNeeded > 0 {
            return "exclamationmark.circle"
        }
        return "checkmark.circle.fill"
    }

    var planStatusSystemImage: String {
        planStatusSystemImage(planData)
    }

    func planStatusStyle(_ data: OfficePlanViewDataSnapshot) -> DSStatusPillStyle {
        if data.remainingOfficeDays > data.candidateDates.count {
            return .critical
        }
        if data.summary.reviewRequiredDays > 0 || data.additionalPlansNeeded > 0 {
            return .warning
        }
        return .success
    }

    var planStatusStyle: DSStatusPillStyle {
        planStatusStyle(planData)
    }

    func planAccentColor(_ data: OfficePlanViewDataSnapshot) -> Color {
        switch planStatusStyle(data) {
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

    var planAccentColor: Color {
        planAccentColor(planData)
    }

    func suggestButtonTitle(_ data: OfficePlanViewDataSnapshot) -> String {
        if data.remainingOfficeDays == 0 {
            return "Target met"
        }
        if data.additionalPlansNeeded == 0 {
            return "Plan complete"
        }
        return data.additionalPlansNeeded == 1
            ? "Suggest 1 day"
            : "Suggest \(data.additionalPlansNeeded) days"
    }

    var suggestButtonTitle: String {
        suggestButtonTitle(planData)
    }

    func removeUnavailablePlansTitle(_ data: OfficePlanViewDataSnapshot) -> String {
        data.invalidSelectedDates.count == 1
            ? "Remove 1 unavailable plan"
            : "Remove \(data.invalidSelectedDates.count) unavailable plans"
    }

    var removeUnavailablePlansTitle: String {
        removeUnavailablePlansTitle(planData)
    }

    func unreachableTargetMessage(_ data: OfficePlanViewDataSnapshot) -> String {
        let availableDays = data.candidateDates.count
        let availableLabel = availableDays == 1
            ? "1 eligible workday remains"
            : "\(availableDays) eligible workdays remain"
        let targetLabel = data.summary.requiredOfficeDays == 1
            ? "the 1-day target"
            : "the \(data.summary.requiredOfficeDays)-day target"
        return "\(availableLabel), so \(targetLabel) is not reachable."
    }

    var unreachableTargetMessage: String {
        unreachableTargetMessage(planData)
    }

    func reviewRequiredMessage(_ data: OfficePlanViewDataSnapshot) -> String {
        let count = data.summary.reviewRequiredDays
        let dayLabel = count == 1 ? "1 day still needs" : "\(count) days still need"
        return "Based on confirmed attendance. \(dayLabel) review, so this plan may change."
    }

    var reviewRequiredMessage: String {
        reviewRequiredMessage(planData)
    }

    func dateState(for date: Date, in data: OfficePlanViewDataSnapshot) -> OfficePlanDateState {
        let date = calendar.startOfDay(for: date)
        guard data.range.contains(date, calendar: calendar) else {
            return .outsideMonth
        }
        if data.holidayDates.contains(date) {
            return .holiday
        }
        if data.leaveDates.contains(date) {
            return .leave
        }
        if data.exclusionDates.contains(date) {
            return .excluded
        }
        if data.completedOfficeDates.contains(date) {
            return .completed
        }
        if data.validSelectedDates.contains(date) {
            return .planned
        }
        if data.candidateDateSet.contains(date), isPreferred(date, in: data) {
            return .preferred
        }
        if data.candidateDateSet.contains(date) {
            return .available
        }
        return .unavailable
    }

    func dateState(for date: Date) -> OfficePlanDateState {
        dateState(for: date, in: planData)
    }

    func dayAction(for date: Date, in data: OfficePlanViewDataSnapshot) -> (() -> Void)? {
        let date = calendar.startOfDay(for: date)
        guard data.candidateDateSet.contains(date) else {
            return nil
        }
        return {
            updatePlan(for: date, isSelected: !data.selectedDates.contains(date))
        }
    }

    func dayAction(for date: Date) -> (() -> Void)? {
        dayAction(for: date, in: planData)
    }

    func isInDisplayedMonth(_ date: Date, in data: OfficePlanViewDataSnapshot) -> Bool {
        data.range.contains(date, calendar: calendar)
    }

    func isInDisplayedMonth(_ date: Date) -> Bool {
        isInDisplayedMonth(date, in: planData)
    }

    func isPreferred(_ date: Date, in data: OfficePlanViewDataSnapshot) -> Bool {
        data.preferredISOWeekdays.contains(calendar.isoWeekday(for: date))
    }

    func isPreferred(_ date: Date) -> Bool {
        isPreferred(date, in: planData)
    }

    func weekPlanText(_ week: OfficePlanWeek, in data: OfficePlanViewDataSnapshot) -> String {
        let plannedCount = data.validSelectedDates.intersection(Set(week.dates)).count
        let recommendedCount = data.recommendedCountsByWeek[week.start, default: 0]
        guard recommendedCount > 0 else {
            return plannedCount == 1 ? "1 planned" : "\(plannedCount) planned"
        }
        return "\(plannedCount) of \(recommendedCount)"
    }

    func weekPlanText(_ week: OfficePlanWeek) -> String {
        weekPlanText(week, in: planData)
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
