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
        var affectedDates: Set<Date> = [calendar.startOfDay(for: event.occurredAt)]

        guard let visit = LocationVisitResolver().visits(from: events).first(where: {
            $0.entryEventID == event.id || $0.exitEventID == event.id
        }) else {
            return affectedDates
        }

        affectedDates.formUnion(dates(from: visit.enteredAt, through: visit.exitedAt))
        return affectedDates
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
