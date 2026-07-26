import Foundation

struct OfficePlanSuggestionService {
    func suggestedDates(
        from candidateDates: [Date],
        excluding selectedDates: Set<Date>,
        count: Int,
        preferredISOWeekdays: Set<Int>,
        calendar: Calendar
    ) -> [Date] {
        guard count > 0 else {
            return []
        }

        return candidateDates
            .filter { !selectedDates.contains($0) }
            .sorted { lhs, rhs in
                let lhsIsPreferred = preferredISOWeekdays.contains(calendar.isoWeekday(for: lhs))
                let rhsIsPreferred = preferredISOWeekdays.contains(calendar.isoWeekday(for: rhs))

                if lhsIsPreferred != rhsIsPreferred {
                    return lhsIsPreferred
                }
                return lhs < rhs
            }
            .prefix(count)
            .map { $0 }
    }
}
