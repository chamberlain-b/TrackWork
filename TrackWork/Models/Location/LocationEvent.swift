import Foundation
import SwiftData

enum LocationEventKind: String, Codable, CaseIterable, Identifiable {
    case entered
    case exited

    var id: String { rawValue }
}

@Model
final class LocationEvent {
    @Attribute(.unique) var id: UUID
    var placeId: UUID?
    var placeName: String
    var placeTypeRaw: String
    var eventKindRaw: String
    var regionIdentifier: String
    var occurredAt: Date
    var createdAt: Date

    init(
        id: UUID = UUID(),
        placeId: UUID? = nil,
        placeName: String,
        placeType: PlaceType,
        eventKind: LocationEventKind,
        regionIdentifier: String,
        occurredAt: Date = .now,
        createdAt: Date = .now
    ) {
        self.id = id
        self.placeId = placeId
        self.placeName = placeName
        self.placeTypeRaw = placeType.rawValue
        self.eventKindRaw = eventKind.rawValue
        self.regionIdentifier = regionIdentifier
        self.occurredAt = occurredAt
        self.createdAt = createdAt
    }
}

extension LocationEvent {
    var placeType: PlaceType? {
        PlaceType(rawValue: placeTypeRaw)
    }

    var eventKind: LocationEventKind? {
        LocationEventKind(rawValue: eventKindRaw)
    }
}

extension LocationEventKind {
    var displayName: String {
        switch self {
        case .entered:
            "Entered"
        case .exited:
            "Exited"
        }
    }

    var systemImageName: String {
        switch self {
        case .entered:
            "arrow.down.forward.circle.fill"
        case .exited:
            "arrow.up.forward.circle.fill"
        }
    }
}
