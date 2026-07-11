import SwiftData
import XCTest
@testable import TrackWork

final class LocalJSONHolidayProviderTests: XCTestCase {
    private var provider: LocalJSONHolidayProvider!
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()

        provider = LocalJSONHolidayProvider()

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
    }

    override func tearDown() {
        provider = nil
        calendar = nil

        super.tearDown()
    }

    func testAUVIC2026FixtureLoads() throws {
        let holidays = try provider.holidays(for: .australia, jurisdictionId: "AU-VIC", year: 2026)

        XCTAssertEqual(holidays.count, 14)
        XCTAssertTrue(holidays.containsHoliday(named: "New Year's Day", on: "2026-01-01", calendar: calendar))
        XCTAssertTrue(holidays.containsHoliday(named: "Melbourne Cup Day", on: "2026-11-03", calendar: calendar))
        XCTAssertTrue(holidays.containsHoliday(named: "Friday before the AFL Grand Final", on: "2026-09-25", calendar: calendar))
        XCTAssertTrue(holidays.containsHoliday(named: "Additional public holiday for Boxing Day", on: "2026-12-28", calendar: calendar))
        XCTAssertEqual(holidays.map(\.date), holidays.map(\.date).sorted())
    }

    func testNZNational2026FixtureLoads() throws {
        let holidays = try provider.holidays(for: .newZealand, jurisdictionId: "NZ-NATIONAL", year: 2026)

        XCTAssertEqual(holidays.count, 13)
        XCTAssertTrue(holidays.containsHoliday(named: "Waitangi Day", on: "2026-02-06", calendar: calendar))
        XCTAssertTrue(holidays.containsHoliday(named: "Matariki", on: "2026-07-10", calendar: calendar))
        XCTAssertTrue(holidays.containsHoliday(named: "Anzac Day (observed)", on: "2026-04-27", calendar: calendar))
        XCTAssertTrue(holidays.containsHoliday(named: "Boxing Day (observed)", on: "2026-12-28", calendar: calendar))
        XCTAssertTrue(holidays.allSatisfy { $0.jurisdictionId == "NZ-NATIONAL" })
    }

    func testNZAucklandInheritanceIncludesNationalAndRegionalHolidays() throws {
        let holidays = try provider.holidays(for: .newZealand, jurisdictionId: "NZ-AUCKLAND", year: 2026)

        XCTAssertEqual(holidays.count, 14)
        XCTAssertTrue(holidays.containsHoliday(named: "New Year's Day", on: "2026-01-01", calendar: calendar))
        XCTAssertTrue(holidays.containsHoliday(named: "Auckland Anniversary Day", on: "2026-01-26", calendar: calendar))
        XCTAssertTrue(holidays.containsHoliday(named: "Matariki", on: "2026-07-10", calendar: calendar))
        XCTAssertTrue(holidays.allSatisfy { $0.jurisdictionId == "NZ-AUCKLAND" })
        XCTAssertTrue(holidays.contains { $0.name == "Matariki" && !$0.isRegional })
        XCTAssertTrue(holidays.contains { $0.jurisdictionId == "NZ-AUCKLAND" && $0.isRegional })
    }

    func testEveryCatalogJurisdictionHasVerified2026Data() throws {
        for jurisdiction in JurisdictionCatalog.all {
            let holidays = try provider.holidays(
                for: jurisdiction.country,
                jurisdictionId: jurisdiction.id,
                year: 2026
            )

            XCTAssertFalse(holidays.isEmpty, jurisdiction.id)
            XCTAssertTrue(holidays.allSatisfy { $0.jurisdictionId == jurisdiction.id }, jurisdiction.id)
            XCTAssertTrue(holidays.allSatisfy { !$0.sourceName.isEmpty }, jurisdiction.id)
            XCTAssertTrue(holidays.allSatisfy { $0.sourceURL?.hasPrefix("https://") == true }, jurisdiction.id)
        }
    }

    func testRegionalAnniversaryFixturesUseOfficialObservedDates() throws {
        let expectedDates = [
            "NZ-NORTHLAND": "2026-01-26",
            "NZ-AUCKLAND": "2026-01-26",
            "NZ-TARANAKI": "2026-03-09",
            "NZ-HAWKES-BAY": "2026-10-23",
            "NZ-WELLINGTON": "2026-01-19",
            "NZ-MARLBOROUGH": "2026-11-02",
            "NZ-NELSON": "2026-02-02",
            "NZ-CANTERBURY": "2026-11-13",
            "NZ-SOUTH-CANTERBURY": "2026-09-28",
            "NZ-WESTLAND": "2026-11-30",
            "NZ-OTAGO": "2026-03-23",
            "NZ-SOUTHLAND": "2026-04-07",
            "NZ-CHATHAM-ISLANDS": "2026-11-30"
        ]

        for (jurisdictionId, date) in expectedDates {
            let holidays = try provider.holidays(
                for: .newZealand,
                jurisdictionId: jurisdictionId,
                year: 2026
            )

            XCTAssertTrue(
                holidays.contains { holiday in
                    holiday.isRegional && calendar.isDate(holiday.date, inSameDayAs: self.date(date))
                },
                jurisdictionId
            )
        }
    }

    func testMissingFixtureThrowsTypedError() {
        XCTAssertThrowsError(try provider.holidays(for: .australia, jurisdictionId: "AU-NSW", year: 2099)) { error in
            XCTAssertEqual(error as? HolidayProviderError, .missingFile(fileName: "holidays_au_nsw_2099"))
        }
    }

    func testUnsupportedJurisdictionThrowsTypedErrorBeforeLoading() {
        XCTAssertThrowsError(try provider.holidays(for: .australia, jurisdictionId: "AU-UNKNOWN", year: 2026)) { error in
            XCTAssertEqual(
                error as? HolidayProviderError,
                .unsupportedJurisdiction(countryCode: "AU", jurisdictionId: "AU-UNKNOWN")
            )
        }
    }

    func testUnverifiedFixtureIsRejected() {
        let provider = provider(withFixture: fixtureJSON(verifiedExhaustive: false))

        XCTAssertThrowsError(try provider.holidays(for: .australia, jurisdictionId: "AU-VIC", year: 2026)) { error in
            XCTAssertEqual(error as? HolidayProviderError, .unverifiedFile(fileName: "holidays_au_vic_2026"))
        }
    }

    func testOutOfYearDateIsRejected() {
        let provider = provider(withFixture: fixtureJSON(date: "2027-01-01"))

        XCTAssertThrowsError(try provider.holidays(for: .australia, jurisdictionId: "AU-VIC", year: 2026)) { error in
            guard let providerError = error as? HolidayProviderError,
                  case .invalidData(_, let reason) = providerError
            else {
                return XCTFail("Expected invalidData, received \(error)")
            }
            XCTAssertTrue(reason.contains("falls outside 2026"))
        }
    }

    @MainActor
    func testHolidaySyncIsIdempotentAndPreservesUserEdits() throws {
        let schema = Schema([PublicHoliday.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let syncService = HolidaySyncService(provider: provider, calendar: calendar)

        try syncService.sync(
            country: .australia,
            jurisdictionId: "AU-VIC",
            years: [2026],
            in: context
        )
        try syncService.sync(
            country: .australia,
            jurisdictionId: "AU-VIC",
            years: [2026],
            in: context
        )

        var persistedHolidays = try context.fetch(FetchDescriptor<PublicHoliday>())
        XCTAssertEqual(persistedHolidays.count, 14)

        let editedHoliday = try XCTUnwrap(persistedHolidays.first { $0.name == "New Year's Day" })
        editedHoliday.name = "My New Year Holiday"
        editedHoliday.isUserEdited = true
        try context.save()

        try syncService.sync(
            country: .australia,
            jurisdictionId: "AU-VIC",
            years: [2026],
            in: context
        )

        persistedHolidays = try context.fetch(FetchDescriptor<PublicHoliday>())
        XCTAssertEqual(persistedHolidays.count, 14)
        XCTAssertTrue(persistedHolidays.contains { $0.name == "My New Year Holiday" && $0.isUserEdited })
    }

    private func date(_ isoDate: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: isoDate) ?? Date(timeIntervalSince1970: 0)
    }

    private func provider(withFixture json: String) -> LocalJSONHolidayProvider {
        LocalJSONHolidayProvider(
            fixtureData: ["holidays_au_vic_2026": Data(json.utf8)],
            calendar: calendar
        )
    }

    private func fixtureJSON(
        date: String = "2026-01-01",
        verifiedExhaustive: Bool = true
    ) -> String {
        """
        {
          "schemaVersion": "1.0",
          "countryCode": "AU",
          "jurisdictionCode": "AU-VIC",
          "year": 2026,
          "sourceName": "Official source",
          "sourceURL": "https://example.gov.au/holidays",
          "verifiedExhaustive": \(verifiedExhaustive),
          "holidays": [{ "date": "\(date)", "name": "Test Holiday" }]
        }
        """
    }
}

private extension Array where Element == PublicHoliday {
    func containsHoliday(named name: String, on isoDate: String, calendar: Calendar) -> Bool {
        contains { holiday in
            holiday.name == name && calendar.isDate(holiday.date, inSameDayAs: date(isoDate, calendar: calendar))
        }
    }

    private func date(_ isoDate: String, calendar: Calendar) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        return formatter.date(from: isoDate) ?? Date(timeIntervalSince1970: 0)
    }
}
