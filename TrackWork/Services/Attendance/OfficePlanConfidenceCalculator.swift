import Foundation

struct OfficePlanConfidence: Equatable {
    enum State: Equatable {
        case targetMet
        case covered
        case needsReview(Int)
        case shortfall(Int)
        case notReachable
    }

    let state: State
    let requiredOfficeDays: Int
    let completedOfficeDays: Int
    let remainingOfficeDays: Int
    let plannedOfficeDates: [Date]
    let completionDate: Date?
    let nextPlannedDate: Date?

    var confirmedProgress: Double {
        guard requiredOfficeDays > 0 else {
            return 0
        }

        return min(Double(completedOfficeDays) / Double(requiredOfficeDays), 1)
    }
}

struct OfficePlanConfidenceCalculator {
    struct Input {
        let requiredOfficeDays: Int
        let completedOfficeDates: Set<Date>
        let plannedOfficeDates: [Date]
        let possibleRemainingOfficeDates: Int
        let reviewRequiredDays: Int
        let evaluationDate: Date
        let calendar: Calendar
    }

    func evaluate(_ input: Input) -> OfficePlanConfidence {
        let today = input.calendar.startOfDay(for: input.evaluationDate)
        let completedDates = Set(
            input.completedOfficeDates.map { input.calendar.startOfDay(for: $0) }
        )
        .filter { $0 <= today }
        let plannedDates = Set(
            input.plannedOfficeDates.map { input.calendar.startOfDay(for: $0) }
        )
        .subtracting(completedDates)
        .filter { $0 >= today }
        .sorted()

        let requiredOfficeDays = max(0, input.requiredOfficeDays)
        let completedOfficeDays = completedDates.count
        let remainingOfficeDays = max(0, requiredOfficeDays - completedOfficeDays)

        let state: OfficePlanConfidence.State
        if remainingOfficeDays == 0 {
            state = .targetMet
        } else if input.reviewRequiredDays > 0 {
            state = .needsReview(input.reviewRequiredDays)
        } else if input.possibleRemainingOfficeDates < remainingOfficeDays {
            state = .notReachable
        } else if plannedDates.count >= remainingOfficeDays {
            state = .covered
        } else {
            state = .shortfall(remainingOfficeDays - plannedDates.count)
        }

        return OfficePlanConfidence(
            state: state,
            requiredOfficeDays: requiredOfficeDays,
            completedOfficeDays: completedOfficeDays,
            remainingOfficeDays: remainingOfficeDays,
            plannedOfficeDates: plannedDates,
            completionDate: completionDate(
                state: state,
                requiredOfficeDays: requiredOfficeDays,
                completedDates: completedDates.sorted(),
                remainingOfficeDays: remainingOfficeDays,
                plannedDates: plannedDates
            ),
            nextPlannedDate: plannedDates.first
        )
    }

    private func completionDate(
        state: OfficePlanConfidence.State,
        requiredOfficeDays: Int,
        completedDates: [Date],
        remainingOfficeDays: Int,
        plannedDates: [Date]
    ) -> Date? {
        switch state {
        case .targetMet:
            guard requiredOfficeDays > 0, completedDates.count >= requiredOfficeDays else {
                return nil
            }
            return completedDates[requiredOfficeDays - 1]
        case .covered:
            guard remainingOfficeDays > 0, plannedDates.count >= remainingOfficeDays else {
                return nil
            }
            return plannedDates[remainingOfficeDays - 1]
        case .needsReview, .shortfall, .notReachable:
            return nil
        }
    }
}
