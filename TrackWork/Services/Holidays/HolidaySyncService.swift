import Foundation
import SwiftData

@MainActor
final class HolidaySyncService {
    private let provider: HolidayProvider
    private let calendar: Calendar

    init(
        provider: HolidayProvider? = nil,
        calendar: Calendar? = nil
    ) {
        self.provider = provider ?? LocalJSONHolidayProvider()
        self.calendar = calendar ?? Self.makeDefaultCalendar()
    }

    @discardableResult
    func sync(
        country: Country,
        jurisdictionId: String,
        years: Set<Int>,
        in modelContext: ModelContext
    ) throws -> [PublicHoliday] {
        let requestedYears = years.sorted()
        let loadedHolidays = try requestedYears.flatMap { year in
            try provider.holidays(for: country, jurisdictionId: jurisdictionId, year: year)
        }
        let loadedIDs = Set(loadedHolidays.map(\.id))
        let existingHolidays = try modelContext.fetch(FetchDescriptor<PublicHoliday>())
        let matchingJurisdiction = existingHolidays.filter {
            $0.countryCode == country.rawValue && $0.jurisdictionId == jurisdictionId
        }
        let existingByID = Dictionary(uniqueKeysWithValues: matchingJurisdiction.map { ($0.id, $0) })

        for loadedHoliday in loadedHolidays {
            if let existingHoliday = existingByID[loadedHoliday.id] {
                guard !existingHoliday.isUserEdited else {
                    continue
                }

                update(existingHoliday, from: loadedHoliday)
            } else {
                modelContext.insert(loadedHoliday)
            }
        }

        for existingHoliday in matchingJurisdiction where !existingHoliday.isUserEdited {
            let year = calendar.component(.year, from: existingHoliday.date)
            if years.contains(year), !loadedIDs.contains(existingHoliday.id) {
                modelContext.delete(existingHoliday)
            }
        }

        try modelContext.save()
        return loadedHolidays
    }

    private func update(_ holiday: PublicHoliday, from replacement: PublicHoliday) {
        holiday.date = replacement.date
        holiday.name = replacement.name
        holiday.countryCode = replacement.countryCode
        holiday.jurisdictionId = replacement.jurisdictionId
        holiday.isRegional = replacement.isRegional
        holiday.sourceName = replacement.sourceName
        holiday.sourceURL = replacement.sourceURL
        holiday.updatedAt = replacement.updatedAt
    }

    private static func makeDefaultCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
