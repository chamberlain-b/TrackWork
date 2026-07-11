import Foundation

final class LocalJSONHolidayProvider: HolidayProvider {
    private let bundle: Bundle
    private let fixtureData: [String: Data]?
    private let decoder: JSONDecoder
    private let calendar: Calendar

    init(
        bundle: Bundle = Bundle(for: HolidayBundleMarker.self),
        decoder: JSONDecoder = JSONDecoder(),
        calendar: Calendar = HolidayDateParser.calendar
    ) {
        self.bundle = bundle
        self.fixtureData = nil
        self.decoder = decoder
        self.calendar = calendar
    }

    init(
        fixtureData: [String: Data],
        decoder: JSONDecoder = JSONDecoder(),
        calendar: Calendar = HolidayDateParser.calendar
    ) {
        self.bundle = .main
        self.fixtureData = fixtureData
        self.decoder = decoder
        self.calendar = calendar
    }

    func holidays(for country: Country, jurisdictionId: String, year: Int) throws -> [PublicHoliday] {
        guard JurisdictionCatalog.jurisdictions(for: country).contains(where: { $0.id == jurisdictionId }) else {
            throw HolidayProviderError.unsupportedJurisdiction(
                countryCode: country.rawValue,
                jurisdictionId: jurisdictionId
            )
        }

        var visitedJurisdictions = Set<String>()
        let entries = try resolvedEntries(
            for: country,
            jurisdictionId: jurisdictionId,
            effectiveJurisdictionId: jurisdictionId,
            year: year,
            visitedJurisdictions: &visitedJurisdictions
        )

        return merged(entries)
            .sorted { lhs, rhs in
                if lhs.date == rhs.date {
                    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }

                return lhs.date < rhs.date
            }
            .map { entry in
                PublicHoliday(
                    id: StableHolidayID.uuid(for: entry.identity),
                    date: entry.date,
                    name: entry.name,
                    country: country,
                    jurisdictionId: entry.jurisdictionId,
                    isRegional: entry.isRegional,
                    sourceName: entry.sourceName,
                    sourceURL: entry.sourceURL,
                    isUserEdited: false,
                    createdAt: entry.date,
                    updatedAt: entry.date
                )
            }
    }

    private func resolvedEntries(
        for country: Country,
        jurisdictionId: String,
        effectiveJurisdictionId: String,
        year: Int,
        visitedJurisdictions: inout Set<String>
    ) throws -> [ResolvedHolidayEntry] {
        guard visitedJurisdictions.insert(jurisdictionId).inserted else {
            throw HolidayProviderError.invalidData(
                fileName: fileName(for: jurisdictionId, year: year),
                reason: "Inheritance cycle includes \(jurisdictionId)."
            )
        }

        let fixture = try loadFixture(for: country, jurisdictionId: jurisdictionId, year: year)
        var entries: [ResolvedHolidayEntry] = []

        for inheritedJurisdictionId in fixture.inheritsFrom {
            entries.append(
                contentsOf: try resolvedEntries(
                    for: country,
                    jurisdictionId: inheritedJurisdictionId,
                    effectiveJurisdictionId: effectiveJurisdictionId,
                    year: year,
                    visitedJurisdictions: &visitedJurisdictions
                )
            )
        }

        entries.append(contentsOf: try fixture.holidays.map { entry in
            let date = try HolidayDateParser.date(
                from: entry.date,
                fileName: fileName(for: jurisdictionId, year: year)
            )

            return ResolvedHolidayEntry(
                date: calendar.startOfDay(for: date),
                name: entry.name,
                country: country,
                jurisdictionId: effectiveJurisdictionId,
                isRegional: fixture.jurisdictionCode != "NZ-NATIONAL" && country == .newZealand,
                sourceName: entry.sourceName ?? fixture.sourceName,
                sourceURL: entry.sourceURL ?? fixture.sourceURL
            )
        })

        visitedJurisdictions.remove(jurisdictionId)
        return entries
    }

    private func loadFixture(for country: Country, jurisdictionId: String, year: Int) throws -> HolidayFixture {
        let fileName = fileName(for: jurisdictionId, year: year)

        do {
            let data: Data
            if let fixtureData {
                guard let injectedData = fixtureData[fileName] else {
                    throw HolidayProviderError.missingFile(fileName: fileName)
                }
                data = injectedData
            } else {
                guard let url = bundle.url(forResource: fileName, withExtension: "json") else {
                    throw HolidayProviderError.missingFile(fileName: fileName)
                }
                data = try Data(contentsOf: url)
            }

            let fixture = try decoder.decode(HolidayFixture.self, from: data)
            try validate(fixture, expectedCountry: country, expectedJurisdictionId: jurisdictionId, expectedYear: year, fileName: fileName)
            return fixture
        } catch let error as HolidayProviderError {
            throw error
        } catch {
            throw HolidayProviderError.invalidData(fileName: fileName, reason: error.localizedDescription)
        }
    }

    private func validate(
        _ fixture: HolidayFixture,
        expectedCountry: Country,
        expectedJurisdictionId: String,
        expectedYear: Int,
        fileName: String
    ) throws {
        guard fixture.schemaVersion == "1.0" else {
            throw HolidayProviderError.invalidData(fileName: fileName, reason: "Unsupported schema version \(fixture.schemaVersion).")
        }

        guard fixture.countryCode == expectedCountry.rawValue else {
            throw HolidayProviderError.invalidData(fileName: fileName, reason: "Expected country \(expectedCountry.rawValue), found \(fixture.countryCode).")
        }

        guard fixture.jurisdictionCode == expectedJurisdictionId else {
            throw HolidayProviderError.invalidData(fileName: fileName, reason: "Expected jurisdiction \(expectedJurisdictionId), found \(fixture.jurisdictionCode).")
        }

        guard fixture.year == expectedYear else {
            throw HolidayProviderError.invalidData(fileName: fileName, reason: "Expected year \(expectedYear), found \(fixture.year).")
        }

        guard fixture.verifiedExhaustive else {
            throw HolidayProviderError.unverifiedFile(fileName: fileName)
        }

        guard !fixture.sourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              isValidSourceURL(fixture.sourceURL)
        else {
            throw HolidayProviderError.invalidData(fileName: fileName, reason: "The fixture source metadata is missing or invalid.")
        }

        let expectedJurisdiction = JurisdictionCatalog.all.first { $0.id == expectedJurisdictionId }
        guard expectedJurisdiction?.country == expectedCountry else {
            throw HolidayProviderError.invalidData(fileName: fileName, reason: "The jurisdiction is not in the supported catalog for \(expectedCountry.rawValue).")
        }

        if expectedCountry == .australia, !fixture.inheritsFrom.isEmpty {
            throw HolidayProviderError.invalidData(fileName: fileName, reason: "Australian jurisdiction fixtures cannot inherit holidays.")
        }

        if expectedJurisdictionId == "NZ-NATIONAL", !fixture.inheritsFrom.isEmpty {
            throw HolidayProviderError.invalidData(fileName: fileName, reason: "NZ-NATIONAL cannot inherit another jurisdiction.")
        }

        for inheritedJurisdictionId in fixture.inheritsFrom {
            guard inheritedJurisdictionId != expectedJurisdictionId else {
                throw HolidayProviderError.invalidData(fileName: fileName, reason: "A fixture cannot inherit itself.")
            }

            guard inheritedJurisdictionId == "NZ-NATIONAL" else {
                throw HolidayProviderError.invalidData(
                    fileName: fileName,
                    reason: "Regional New Zealand fixtures may inherit only NZ-NATIONAL."
                )
            }
        }

        var dates = Set<String>()
        for entry in fixture.holidays {
            let normalizedName = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedName.isEmpty else {
                throw HolidayProviderError.invalidData(fileName: fileName, reason: "Holiday names cannot be empty.")
            }

            let date = try HolidayDateParser.date(from: entry.date, fileName: fileName)
            guard calendar.component(.year, from: date) == expectedYear else {
                throw HolidayProviderError.invalidData(
                    fileName: fileName,
                    reason: "Holiday date \(entry.date) falls outside \(expectedYear)."
                )
            }

            guard dates.insert(entry.date).inserted else {
                throw HolidayProviderError.invalidData(fileName: fileName, reason: "Duplicate holiday date \(entry.date).")
            }

            if let sourceName = entry.sourceName,
               sourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw HolidayProviderError.invalidData(fileName: fileName, reason: "A holiday source name is empty.")
            }

            if let sourceURL = entry.sourceURL, !isValidSourceURL(sourceURL) {
                throw HolidayProviderError.invalidData(fileName: fileName, reason: "A holiday source URL is invalid.")
            }
        }
    }

    private func isValidSourceURL(_ value: String) -> Bool {
        guard let url = URL(string: value) else {
            return false
        }

        return url.scheme == "https" && url.host != nil
    }

    private func merged(_ entries: [ResolvedHolidayEntry]) -> [ResolvedHolidayEntry] {
        entries.reduce(into: [Date: ResolvedHolidayEntry]()) { result, entry in
            result[entry.date] = entry
        }
        .map(\.value)
    }

    private func fileName(for jurisdictionId: String, year: Int) -> String {
        "holidays_\(jurisdictionId.lowercased().replacingOccurrences(of: "-", with: "_"))_\(year)"
    }
}

private final class HolidayBundleMarker: NSObject {}

private struct ResolvedHolidayEntry {
    let date: Date
    let name: String
    let country: Country
    let jurisdictionId: String
    let isRegional: Bool
    let sourceName: String
    let sourceURL: String

    var identity: String {
        [country.rawValue, jurisdictionId, HolidayDateParser.string(from: date), name].joined(separator: "|")
    }
}

private enum HolidayDateParser {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func date(from value: String, fileName: String) throws -> Date {
        guard let date = formatter.date(from: value), string(from: date) == value else {
            throw HolidayProviderError.invalidData(fileName: fileName, reason: "Invalid date \(value). Expected yyyy-MM-dd.")
        }

        return date
    }

    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }
}

private enum StableHolidayID {
    static func uuid(for value: String) -> UUID {
        let bytes = Array(value.utf8)
        var hash: UInt64 = 0xcbf29ce484222325

        for byte in bytes {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }

        let reversedHash = UInt64(bigEndian: hash).byteSwapped
        let uuidBytes: uuid_t = (
            UInt8((hash >> 56) & 0xff),
            UInt8((hash >> 48) & 0xff),
            UInt8((hash >> 40) & 0xff),
            UInt8((hash >> 32) & 0xff),
            UInt8((hash >> 24) & 0xff),
            UInt8((hash >> 16) & 0xff),
            UInt8((hash >> 8) & 0xff),
            UInt8(hash & 0xff),
            UInt8((reversedHash >> 56) & 0xff),
            UInt8((reversedHash >> 48) & 0xff),
            UInt8((reversedHash >> 40) & 0xff),
            UInt8((reversedHash >> 32) & 0xff),
            UInt8((reversedHash >> 24) & 0xff),
            UInt8((reversedHash >> 16) & 0xff),
            UInt8((reversedHash >> 8) & 0xff),
            UInt8(reversedHash & 0xff)
        )

        return UUID(uuid: uuidBytes)
    }
}
