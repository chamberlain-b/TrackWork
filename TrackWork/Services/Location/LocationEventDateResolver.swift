import Foundation

struct LocationEventDateResolver {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func affectedDates(from events: [LocationEvent]) -> Set<Date> {
        var affectedDates = Set(events.map { calendar.startOfDay(for: $0.occurredAt) })

        for visit in LocationVisitResolver().visits(from: events) {
            affectedDates.formUnion(dates(from: visit.enteredAt, through: visit.exitedAt))
        }

        return affectedDates
    }

    func affectedDates(for event: LocationEvent, among events: [LocationEvent]) -> Set<Date> {
        // A late/repeated event can replace a pairing on either side of midnight.
        // Re-evaluate the nearby journal evidence, including the pairing it replaces.
        let nearbyEvents = events.filter {
            $0.regionIdentifier == event.regionIdentifier
                && abs($0.occurredAt.timeIntervalSince(event.occurredAt))
                    <= LocationVisitResolver.maximumVisitDuration
        }
        return affectedDates(from: nearbyEvents).union([calendar.startOfDay(for: event.occurredAt)])
    }

    private func dates(from periodStart: Date, through periodEnd: Date) -> [Date] {
        var dates: [Date] = []
        var currentDate = calendar.startOfDay(for: periodStart)
        let finalDate = calendar.startOfDay(for: periodEnd)

        while currentDate <= finalDate {
            dates.append(currentDate)
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }

        return dates
    }
}
