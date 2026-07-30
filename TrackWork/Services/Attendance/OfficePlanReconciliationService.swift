import Foundation

struct OfficePlanReconciliation {
    let plansToDelete: [PlannedOfficeDay]
    let datesToInsert: [Date]
}

struct OfficePlanReconciliationService {
    func changes(
        existingPlans: [PlannedOfficeDay],
        desiredDates: [Date],
        range: ComplianceDateRange,
        calendar: Calendar
    ) -> OfficePlanReconciliation {
        let normalizedDesiredDates = Set(
            desiredDates.map { calendar.startOfDay(for: $0) }
        )
        let plansInRange = existingPlans.filter {
            range.contains($0.date, calendar: calendar)
        }
        let plansToDelete = plansInRange.filter {
            !normalizedDesiredDates.contains(calendar.startOfDay(for: $0.date))
        }
        let datesToInsert = normalizedDesiredDates
            .filter { desiredDate in
                !plansInRange.contains {
                    calendar.isDate($0.date, inSameDayAs: desiredDate)
                }
            }
            .sorted()

        return OfficePlanReconciliation(
            plansToDelete: plansToDelete,
            datesToInsert: datesToInsert
        )
    }
}
