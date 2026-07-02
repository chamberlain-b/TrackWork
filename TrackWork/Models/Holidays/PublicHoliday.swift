import Foundation
import SwiftData

@Model
final class PublicHoliday {
    @Attribute(.unique) var id: UUID
    var date: Date
    var name: String
    var countryCode: String
    var jurisdictionId: String
    var isRegional: Bool
    var sourceName: String
    var sourceURL: String?
    var isUserEdited: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        date: Date,
        name: String,
        country: Country,
        jurisdictionId: String,
        isRegional: Bool,
        sourceName: String,
        sourceURL: String? = nil,
        isUserEdited: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.date = date
        self.name = name
        self.countryCode = country.rawValue
        self.jurisdictionId = jurisdictionId
        self.isRegional = isRegional
        self.sourceName = sourceName
        self.sourceURL = sourceURL
        self.isUserEdited = isUserEdited
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension PublicHoliday {
    var country: Country? {
        Country(rawValue: countryCode)
    }
}
