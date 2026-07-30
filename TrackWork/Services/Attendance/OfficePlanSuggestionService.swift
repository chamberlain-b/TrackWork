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

    func balancedSuggestedDates(
        from candidateDates: [Date],
        excluding selectedDates: Set<Date>,
        count: Int,
        preferredISOWeekdays: Set<Int>,
        calendar: Calendar
    ) -> [Date] {
        guard count > 0 else {
            return []
        }

        let normalizedCandidates = Set(
            candidateDates.map { calendar.startOfDay(for: $0) }
        )
        let normalizedSelectedDates = Set(
            selectedDates.map { calendar.startOfDay(for: $0) }
        )
        let selectedCandidateDates = normalizedSelectedDates.intersection(normalizedCandidates)
        var remainingCandidates = normalizedCandidates
            .subtracting(selectedCandidateDates)
        var weeklyPlanCounts = Dictionary(
            grouping: selectedCandidateDates,
            by: { weekStart(for: $0, calendar: calendar) }
        )
        .mapValues(\.count)
        var result: [Date] = []

        while result.count < count, !remainingCandidates.isEmpty {
            let candidatesByWeek = Dictionary(
                grouping: remainingCandidates,
                by: { weekStart(for: $0, calendar: calendar) }
            )
            guard let selectedWeek = candidatesByWeek.keys.min(by: { lhs, rhs in
                let lhsCount = weeklyPlanCounts[lhs, default: 0]
                let rhsCount = weeklyPlanCounts[rhs, default: 0]
                return lhsCount == rhsCount ? lhs < rhs : lhsCount < rhsCount
            }), let selectedDate = candidatesByWeek[selectedWeek]?.min(by: { lhs, rhs in
                let lhsIsPreferred = preferredISOWeekdays.contains(
                    calendar.isoWeekday(for: lhs)
                )
                let rhsIsPreferred = preferredISOWeekdays.contains(
                    calendar.isoWeekday(for: rhs)
                )

                if lhsIsPreferred != rhsIsPreferred {
                    return lhsIsPreferred
                }
                return lhs < rhs
            }) else {
                break
            }

            result.append(selectedDate)
            remainingCandidates.remove(selectedDate)
            weeklyPlanCounts[selectedWeek, default: 0] += 1
        }

        return result
    }

    private func weekStart(for date: Date, calendar: Calendar) -> Date {
        let normalizedDate = calendar.startOfDay(for: date)
        let daysFromMonday = calendar.mondayBasedWeekdayIndex(for: normalizedDate)
        return calendar.date(
            byAdding: .day,
            value: -daysFromMonday,
            to: normalizedDate
        ) ?? normalizedDate
    }
}
