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
        assertHoliday("New Year's Day", on: "2026-01-01", in: holidays)
        assertHoliday("Melbourne Cup Day", on: "2026-11-03", in: holidays)
        assertHoliday("Friday before the AFL Grand Final", on: "2026-09-25", in: holidays)
        assertHoliday("Additional public holiday for Boxing Day", on: "2026-12-28", in: holidays)
        XCTAssertEqual(holidays.map(\.date), holidays.map(\.date).sorted())
    }

    func testAUVIC2027FixtureLoads() throws {
        let holidays = try provider.holidays(for: .australia, jurisdictionId: "AU-VIC", year: 2027)

        XCTAssertEqual(holidays.count, 15)
        assertHoliday("New Year's Day", on: "2027-01-01", in: holidays)
        assertHoliday("Melbourne Cup Day", on: "2027-11-02", in: holidays)
        assertHoliday("Friday before the AFL Grand Final", on: "2027-09-24", in: holidays)
        assertHoliday("Additional public holiday for Christmas Day", on: "2027-12-27", in: holidays)
        assertHoliday("Additional public holiday for Boxing Day", on: "2027-12-28", in: holidays)
        XCTAssertTrue(
            holidays.contains {
                $0.name == "Friday before the AFL Grand Final"
                    && $0.sourceName == "Victorian Department of Education 2026–2030 calendar"
            }
        )
        XCTAssertEqual(holidays.map(\.date), holidays.map(\.date).sorted())
    }

    func testNZNational2026FixtureLoads() throws {
        let holidays = try provider.holidays(for: .newZealand, jurisdictionId: "NZ-NATIONAL", year: 2026)

        XCTAssertEqual(holidays.count, 13)
        assertHoliday("Waitangi Day", on: "2026-02-06", in: holidays)
        assertHoliday("Matariki", on: "2026-07-10", in: holidays)
        assertHoliday("Anzac Day (observed)", on: "2026-04-27", in: holidays)
        assertHoliday("Boxing Day (observed)", on: "2026-12-28", in: holidays)
        XCTAssertTrue(holidays.allSatisfy { $0.jurisdictionId == "NZ-NATIONAL" })
    }

    func testNZNational2027FixtureLoadsWithActualAndObservedDates() throws {
        let holidays = try provider.holidays(for: .newZealand, jurisdictionId: "NZ-NATIONAL", year: 2027)

        XCTAssertEqual(holidays.count, 16)
        assertHoliday("Day after New Year's Day", on: "2027-01-02", in: holidays)
        assertHoliday("Day after New Year's Day (observed)", on: "2027-01-04", in: holidays)
        assertHoliday("Waitangi Day (observed)", on: "2027-02-08", in: holidays)
        assertHoliday("Matariki", on: "2027-06-25", in: holidays)
        assertHoliday("Christmas Day (observed)", on: "2027-12-27", in: holidays)
        assertHoliday("Boxing Day (observed)", on: "2027-12-28", in: holidays)
        XCTAssertTrue(holidays.allSatisfy { $0.jurisdictionId == "NZ-NATIONAL" })
    }

    func testNZAucklandInheritanceIncludesNationalAndRegionalHolidays() throws {
        let holidays = try provider.holidays(for: .newZealand, jurisdictionId: "NZ-AUCKLAND", year: 2026)

        XCTAssertEqual(holidays.count, 14)
        assertHoliday("New Year's Day", on: "2026-01-01", in: holidays)
        assertHoliday("Auckland Anniversary Day", on: "2026-01-26", in: holidays)
        assertHoliday("Matariki", on: "2026-07-10", in: holidays)
        XCTAssertTrue(holidays.allSatisfy { $0.jurisdictionId == "NZ-AUCKLAND" })
        XCTAssertTrue(holidays.contains { $0.name == "Matariki" && !$0.isRegional })
        XCTAssertTrue(holidays.contains { $0.jurisdictionId == "NZ-AUCKLAND" && $0.isRegional })
    }

    func testNZAuckland2027InheritanceIncludesNationalAndRegionalHolidays() throws {
        let holidays = try provider.holidays(for: .newZealand, jurisdictionId: "NZ-AUCKLAND", year: 2027)

        XCTAssertEqual(holidays.count, 17)
        assertHoliday("New Year's Day", on: "2027-01-01", in: holidays)
        assertHoliday("Auckland Anniversary Day", on: "2027-02-01", in: holidays)
        assertHoliday("Matariki", on: "2027-06-25", in: holidays)
        XCTAssertTrue(holidays.allSatisfy { $0.jurisdictionId == "NZ-AUCKLAND" })
        XCTAssertTrue(holidays.contains { $0.name == "Matariki" && !$0.isRegional })
        XCTAssertTrue(holidays.contains { $0.name == "Auckland Anniversary Day" && $0.isRegional })
    }

    func testHolidayCoverageMatchesBundledYears() {
        XCTAssertEqual(HolidayCoverage.supportedYears, Set([2026, 2027]))
        XCTAssertEqual(HolidayCoverage.displaySummary, "2026–2027 public holidays")
        XCTAssertEqual(HolidayCoverage.statusText, "Verified through 2027")
        XCTAssertTrue(HolidayCoverage.supports(year: 2026))
        XCTAssertTrue(HolidayCoverage.supports(year: 2027))
        XCTAssertFalse(HolidayCoverage.supports(year: 2028))
    }

    func testHolidayCoverageValidatesInclusiveCrossYearRangesDeterministically() {
        let validation = HolidayCoverage.validation(
            from: date("2025-12-31"),
            through: date("2028-01-01"),
            calendar: calendar
        )

        XCTAssertEqual(validation.requiredYears, [2025, 2026, 2027, 2028])
        XCTAssertEqual(validation.unsupportedYears, [2025, 2028])
        XCTAssertFalse(validation.isSupported)
        XCTAssertEqual(
            validation.userFacingMessage,
            "Public holiday data is not bundled for 2025, 2028. Results for this range may be incomplete. "
                + "Choose dates within 2026–2027."
        )
    }

    func testHolidayCoverageNormalizesReversedRangesAndAcceptsBundledYears() {
        let validation = HolidayCoverage.validation(
            from: date("2027-12-31"),
            through: date("2026-01-01"),
            calendar: calendar
        )

        XCTAssertEqual(validation.requiredYears, [2026, 2027])
        XCTAssertTrue(validation.unsupportedYears.isEmpty)
        XCTAssertTrue(validation.isSupported)
        XCTAssertNil(validation.userFacingMessage)
    }

    func testHolidayCoverageProvidesCurrentYearWarning() {
        let validation = HolidayCoverage.validation(forYear: 2028)

        XCTAssertEqual(validation.requiredYears, [2028])
        XCTAssertEqual(validation.unsupportedYears, [2028])
        XCTAssertEqual(
            validation.userFacingMessage,
            "Public holiday data is not bundled for 2028. Results for this range may be incomplete. "
                + "Choose dates within 2026–2027."
        )
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

    func testEveryCatalogJurisdictionHasVerified2027Data() throws {
        for jurisdiction in JurisdictionCatalog.all {
            let holidays = try provider.holidays(
                for: jurisdiction.country,
                jurisdictionId: jurisdiction.id,
                year: 2027
            )

            XCTAssertFalse(holidays.isEmpty, jurisdiction.id)
            XCTAssertTrue(holidays.allSatisfy { $0.jurisdictionId == jurisdiction.id }, jurisdiction.id)
            XCTAssertTrue(holidays.allSatisfy { !$0.sourceName.isEmpty }, jurisdiction.id)
            XCTAssertTrue(holidays.allSatisfy { $0.sourceURL?.hasPrefix("https://") == true }, jurisdiction.id)
        }
    }

    func testRegionalAnniversaryFixturesUseOfficialObservedDates() throws {
        for (jurisdictionId, date) in RegionalAnniversaryExpectation.dates2026 {
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

    func test2027RegionalAnniversaryFixturesUseOfficialObservedDates() throws {
        for (jurisdictionId, date) in RegionalAnniversaryExpectation.dates2027 {
            let holidays = try provider.holidays(
                for: .newZealand,
                jurisdictionId: jurisdictionId,
                year: 2027
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
        XCTAssertThrowsError(try provider.holidays(for: .australia, jurisdictionId: "AU-NSW", year: 2028)) { error in
            XCTAssertEqual(error as? HolidayProviderError, .missingFile(fileName: "holidays_au_nsw_2028"))
        }
    }

    func testUnsupportedJurisdictionThrowsTypedErrorBeforeLoading() {
        let holidays = {
            try self.provider.holidays(for: .australia, jurisdictionId: "AU-UNKNOWN", year: 2026)
        }

        XCTAssertThrowsError(try holidays()) { error in
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

    private func assertHoliday(_ name: String, on isoDate: String, in holidays: [PublicHoliday]) {
        XCTAssertTrue(holidays.containsHoliday(named: name, on: isoDate, calendar: calendar))
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

private enum RegionalAnniversaryExpectation {
    static let dates2026 = [
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

    static let dates2027 = [
        "NZ-NORTHLAND": "2027-02-01",
        "NZ-AUCKLAND": "2027-02-01",
        "NZ-TARANAKI": "2027-03-08",
        "NZ-HAWKES-BAY": "2027-10-22",
        "NZ-WELLINGTON": "2027-01-25",
        "NZ-MARLBOROUGH": "2027-11-01",
        "NZ-NELSON": "2027-02-01",
        "NZ-CANTERBURY": "2027-11-12",
        "NZ-SOUTH-CANTERBURY": "2027-09-27",
        "NZ-WESTLAND": "2027-11-29",
        "NZ-OTAGO": "2027-03-22",
        "NZ-SOUTHLAND": "2027-03-30",
        "NZ-CHATHAM-ISLANDS": "2027-11-29"
    ]
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
