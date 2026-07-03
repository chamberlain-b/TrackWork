import Foundation
import SwiftData

enum PlaceType: String, Codable, CaseIterable, Identifiable {
    case home
    case office

    var id: String { rawValue }
}

@Model
final class Place {
    @Attribute(.unique) var id: UUID
    var name: String
    var typeRaw: String
    var latitude: Double
    var longitude: Double
    var radiusMeters: Double
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        type: PlaceType,
        latitude: Double,
        longitude: Double,
        radiusMeters: Double = 150,
        isActive: Bool = true,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.typeRaw = type.rawValue
        self.latitude = latitude
        self.longitude = longitude
        self.radiusMeters = radiusMeters
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension PlaceType {
    var displayName: String {
        switch self {
        case .home:
            "Home"
        case .office:
            "Office"
        }
    }

    var defaultName: String {
        switch self {
        case .home:
            "Home"
        case .office:
            "Office"
        }
    }

    var systemImageName: String {
        switch self {
        case .home:
            "house.fill"
        case .office:
            "building.2.fill"
        }
    }
}

extension Place {
    var type: PlaceType? {
        PlaceType(rawValue: typeRaw)
    }
}
