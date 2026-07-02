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

        XCTAssertEqual(holidays.count, 10)
        XCTAssertTrue(holidays.containsHoliday(named: "New Year's Day", on: "2026-01-01", calendar: calendar))
        XCTAssertTrue(holidays.containsHoliday(named: "Melbourne Cup Day", on: "2026-11-03", calendar: calendar))
        XCTAssertEqual(holidays.map(\.date), holidays.map(\.date).sorted())
    }

    func testNZNational2026FixtureLoads() throws {
        let holidays = try provider.holidays(for: .newZealand, jurisdictionId: "NZ-NATIONAL", year: 2026)

        XCTAssertEqual(holidays.count, 11)
        XCTAssertTrue(holidays.containsHoliday(named: "Waitangi Day", on: "2026-02-06", calendar: calendar))
        XCTAssertTrue(holidays.containsHoliday(named: "Matariki", on: "2026-07-10", calendar: calendar))
        XCTAssertTrue(holidays.allSatisfy { $0.jurisdictionId == "NZ-NATIONAL" })
    }

    func testNZAucklandInheritanceIncludesNationalAndRegionalHolidays() throws {
        let holidays = try provider.holidays(for: .newZealand, jurisdictionId: "NZ-AUCKLAND", year: 2026)

        XCTAssertEqual(holidays.count, 12)
        XCTAssertTrue(holidays.containsHoliday(named: "New Year's Day", on: "2026-01-01", calendar: calendar))
        XCTAssertTrue(holidays.containsHoliday(named: "Auckland Anniversary Day", on: "2026-01-26", calendar: calendar))
        XCTAssertTrue(holidays.containsHoliday(named: "Matariki", on: "2026-07-10", calendar: calendar))
        XCTAssertTrue(holidays.contains { $0.jurisdictionId == "NZ-NATIONAL" })
        XCTAssertTrue(holidays.contains { $0.jurisdictionId == "NZ-AUCKLAND" && $0.isRegional })
    }

    func testMissingFixtureThrowsTypedError() {
        XCTAssertThrowsError(try provider.holidays(for: .australia, jurisdictionId: "AU-NSW", year: 2099)) { error in
            XCTAssertEqual(error as? HolidayProviderError, .missingFile(fileName: "holidays_au_nsw_2099"))
        }
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
