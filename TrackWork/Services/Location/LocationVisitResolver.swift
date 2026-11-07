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
        resolve(events).visits
    }

    func openEntries(from events: [LocationEvent]) -> [LocationEvent] {
        resolve(events).openEntries
    }

    private func resolve(_ events: [LocationEvent]) -> (
        visits: [ResolvedLocationVisit], openEntries: [LocationEvent]
    ) {
        var activeByRegion: [String: ActiveVisit] = [:]
        var visits: [ResolvedLocationVisit] = []

        // Core Location sends both a state and a boundary callback for a crossing.
        // Prefer the real boundary when those callbacks describe the same instant,
        // whichever callback reached the journal first.
        var boundaryTimes: [String: [LocationEventKind: [Date]]] = [:]
        for event in events.sorted(by: { Self.eventPrecedes($0, $1) }) {
            guard let kind = event.eventKind, kind == .entered || kind == .exited else { continue }
            boundaryTimes[event.regionIdentifier, default: [:]][kind, default: []].append(event.occurredAt)
        }
        let evidence = events.filter { event in
            guard event.eventKind == .confirmedInside || event.eventKind == .confirmedOutside else {
                return true
            }
            let matchingKind: LocationEventKind = event.eventKind == .confirmedInside ? .entered : .exited
            let times = boundaryTimes[event.regionIdentifier]?[matchingKind] ?? []
            // Binary search avoids a full-journal scan for every observation.
            let lowerBound = event.occurredAt.addingTimeInterval(-5)
            var lower = 0
            var upper = times.count
            while lower < upper {
                let middle = lower + (upper - lower) / 2
                if times[middle] <= lowerBound { lower = middle + 1 } else { upper = middle }
            }
            return lower == times.count || times[lower] >= event.occurredAt.addingTimeInterval(5)
        }
        for event in evidence.sorted(by: { Self.eventPrecedes($0, $1) }) {
            guard event.placeType != nil, let eventKind = event.eventKind else { continue }

            switch eventKind {
            case .entered:
                // A true new entry repairs a missed exit. Keep only the older visit's
                // positively confirmed duration, never the unobserved gap.
                if let previous = activeByRegion[event.regionIdentifier],
                   let confirmedVisit = confirmedVisit(previous) {
                    visits.append(confirmedVisit)
                }
                activeByRegion[event.regionIdentifier] = ActiveVisit(entry: event)
            case .confirmedInside:
                if var active = activeByRegion[event.regionIdentifier],
                   isPlausibleVisit(from: active.entry.occurredAt, to: event.occurredAt) {
                    active.confirmation = event
                    activeByRegion[event.regionIdentifier] = active
                } else if activeByRegion[event.regionIdentifier]?.entry.occurredAt != event.occurredAt {
                    // An initial or stale state observation starts at its own time.
                    // It cannot reconstruct when the user arrived.
                    if let previous = activeByRegion[event.regionIdentifier],
                       let confirmedVisit = confirmedVisit(previous) {
                        visits.append(confirmedVisit)
                    }
                    activeByRegion[event.regionIdentifier] = ActiveVisit(entry: event)
                }
            case .exited:
                guard let active = activeByRegion.removeValue(forKey: event.regionIdentifier) else {
                    continue
                }
                if let visit = visit(from: active.entry, through: event) {
                    visits.append(visit)
                } else if let confirmedVisit = confirmedVisit(active) {
                    visits.append(confirmedVisit)
                }
            case .confirmedOutside, .monitoringStopped:
                // An outside state or stopping monitoring cannot establish when
                // the user left. Keep only previously confirmed duration.
                if let active = activeByRegion.removeValue(forKey: event.regionIdentifier),
                   let confirmedVisit = confirmedVisit(active) {
                    visits.append(confirmedVisit)
                }
            }
        }

        visits.append(contentsOf: activeByRegion.values.compactMap(confirmedVisit))
        return (
            visits.sorted { $0.enteredAt < $1.enteredAt },
            activeByRegion.values.map(\.entry).sorted(by: { Self.eventPrecedes($0, $1) })
        )
    }

    private func confirmedVisit(_ active: ActiveVisit) -> ResolvedLocationVisit? {
        guard let confirmation = active.confirmation else { return nil }
        return visit(from: active.entry, through: confirmation)
    }

    private func visit(from entry: LocationEvent, through end: LocationEvent) -> ResolvedLocationVisit? {
        guard let placeType = entry.placeType,
              isPlausibleVisit(from: entry.occurredAt, to: end.occurredAt) else { return nil }
        return ResolvedLocationVisit(
            entryEventID: entry.id,
            exitEventID: end.id,
            regionIdentifier: entry.regionIdentifier,
            placeType: placeType,
            enteredAt: entry.occurredAt,
            exitedAt: end.occurredAt
        )
    }

    private func isPlausibleVisit(from enteredAt: Date, to exitedAt: Date) -> Bool {
        let duration = exitedAt.timeIntervalSince(enteredAt)
        return duration > 0 && duration <= maximumVisitDuration
    }

    private static func eventPrecedes(_ lhs: LocationEvent, _ rhs: LocationEvent) -> Bool {
        if lhs.occurredAt != rhs.occurredAt { return lhs.occurredAt < rhs.occurredAt }
        // A closing observation wins a same-instant tie, independent of delivery order.
        let order: [LocationEventKind: Int] = [
            .entered: 0, .confirmedInside: 1, .exited: 2, .confirmedOutside: 3, .monitoringStopped: 4
        ]
        let lhsOrder = lhs.eventKind.flatMap { order[$0] } ?? 0
        let rhsOrder = rhs.eventKind.flatMap { order[$0] } ?? 0
        if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}

private struct ActiveVisit {
    let entry: LocationEvent
    var confirmation: LocationEvent?
}
