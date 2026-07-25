import Foundation

struct ResolvedLocationVisit: Equatable {
    let entryEventID: UUID
    let exitEventID: UUID
    let regionIdentifier: String
    let placeType: PlaceType
    let enteredAt: Date
    let exitedAt: Date
}

struct LocationVisitResolver {
    static let maximumVisitDuration: TimeInterval = 18 * 60 * 60

    private let maximumVisitDuration: TimeInterval

    init(maximumVisitDuration: TimeInterval = LocationVisitResolver.maximumVisitDuration) {
        self.maximumVisitDuration = maximumVisitDuration
    }

    func visits(from events: [LocationEvent]) -> [ResolvedLocationVisit] {
        var activeEntryByRegion: [String: LocationEvent] = [:]
        var visits: [ResolvedLocationVisit] = []

        for event in events.sorted(by: { lhs, rhs in
            if lhs.occurredAt == rhs.occurredAt {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.occurredAt < rhs.occurredAt
        }) {
            guard event.placeType != nil, let eventKind = event.eventKind else {
                continue
            }

            switch eventKind {
            case .entered:
                // A newer entry repairs a previously missed exit instead of extending a stale visit.
                activeEntryByRegion[event.regionIdentifier] = event
            case .exited:
                guard let entry = activeEntryByRegion.removeValue(forKey: event.regionIdentifier),
                      let placeType = entry.placeType,
                      isPlausibleVisit(from: entry.occurredAt, to: event.occurredAt) else {
                    continue
                }

                visits.append(
                    ResolvedLocationVisit(
                        entryEventID: entry.id,
                        exitEventID: event.id,
                        regionIdentifier: event.regionIdentifier,
                        placeType: placeType,
                        enteredAt: entry.occurredAt,
                        exitedAt: event.occurredAt
                    )
                )
            }
        }

        return visits
    }

    func openEntries(from events: [LocationEvent]) -> [LocationEvent] {
        var activeEntryByRegion: [String: LocationEvent] = [:]

        for event in events.sorted(by: { lhs, rhs in
            if lhs.occurredAt == rhs.occurredAt {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.occurredAt < rhs.occurredAt
        }) {
            guard event.placeType != nil, let eventKind = event.eventKind else {
                continue
            }

            switch eventKind {
            case .entered:
                activeEntryByRegion[event.regionIdentifier] = event
            case .exited:
                activeEntryByRegion[event.regionIdentifier] = nil
            }
        }

        return activeEntryByRegion.values.sorted { lhs, rhs in
            if lhs.occurredAt == rhs.occurredAt {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.occurredAt < rhs.occurredAt
        }
    }

    private func isPlausibleVisit(from enteredAt: Date, to exitedAt: Date) -> Bool {
        let duration = exitedAt.timeIntervalSince(enteredAt)
        return duration > 0 && duration <= maximumVisitDuration
    }

}
