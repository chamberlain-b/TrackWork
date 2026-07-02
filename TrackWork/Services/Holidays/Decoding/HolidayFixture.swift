import Foundation

struct HolidayFixture: Decodable {
    let schemaVersion: String
    let countryCode: String
    let jurisdictionCode: String
    let year: Int
    let sourceName: String
    let sourceURL: String
    let verifiedExhaustive: Bool
    let inheritsFrom: [String]
    let holidays: [HolidayFixtureEntry]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case countryCode
        case jurisdictionCode
        case year
        case sourceName
        case sourceURL
        case verifiedExhaustive
        case inheritsFrom
        case holidays
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(String.self, forKey: .schemaVersion)
        countryCode = try container.decode(String.self, forKey: .countryCode)
        jurisdictionCode = try container.decode(String.self, forKey: .jurisdictionCode)
        year = try container.decode(Int.self, forKey: .year)
        sourceName = try container.decode(String.self, forKey: .sourceName)
        sourceURL = try container.decode(String.self, forKey: .sourceURL)
        verifiedExhaustive = try container.decode(Bool.self, forKey: .verifiedExhaustive)
        inheritsFrom = try container.decodeIfPresent([String].self, forKey: .inheritsFrom) ?? []
        holidays = try container.decode([HolidayFixtureEntry].self, forKey: .holidays)
    }
}

struct HolidayFixtureEntry: Decodable {
    let date: String
    let name: String
    let sourceName: String
    let sourceURL: String
    let notes: String?
}
