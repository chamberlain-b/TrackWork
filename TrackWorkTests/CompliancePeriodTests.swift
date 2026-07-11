import XCTest
@testable import TrackWork

final class CompliancePeriodTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
    }

    override func tearDown() {
        calendar = nil
        super.tearDown()
    }

    func testBuiltInRangesHaveDeterministicInclusiveBoundaries() {
        let now = date("2026-07-15")
        let expectedRanges: [(CompliancePeriodPreset, String, String)] = [
            (.currentMonth, "2026-07-01", "2026-07-31"),
            (.last30Days, "2026-06-16", "2026-07-15"),
            (.previousMonth, "2026-06-01", "2026-06-30"),
            (.currentQuarter, "2026-07-01", "2026-09-30"),
            (.previousQuarter, "2026-04-01", "2026-06-30"),
            (.yearToDate, "2026-01-01", "2026-07-15")
        ]

        for (preset, expectedStart, expectedEnd) in expectedRanges {
            let range = preset.dateRange(
                calendar: calendar,
                now: now,
                customStart: now,
                customEnd: now
            )

            XCTAssertEqual(range.start, date(expectedStart), preset.rawValue)
            XCTAssertEqual(range.end, date(expectedEnd), preset.rawValue)
            XCTAssertTrue(range.contains(range.start, calendar: calendar), preset.rawValue)
            XCTAssertTrue(range.contains(range.end, calendar: calendar), preset.rawValue)
        }
    }

    func testCustomRangeNormalizesDayTimesAndReversedInput() {
        let later = date("2026-07-10").addingTimeInterval(60 * 60 * 18)
        let earlier = date("2026-07-05").addingTimeInterval(60 * 60 * 8)

        let range = CompliancePeriodPreset.custom.dateRange(
            calendar: calendar,
            now: date("2026-07-15"),
            customStart: later,
            customEnd: earlier
        )

        XCTAssertEqual(range.start, date("2026-07-05"))
        XCTAssertEqual(range.end, date("2026-07-10"))
        XCTAssertTrue(range.contains(date("2026-07-05"), calendar: calendar))
        XCTAssertTrue(range.contains(date("2026-07-10").addingTimeInterval(86_399), calendar: calendar))
        XCTAssertFalse(range.contains(date("2026-07-11"), calendar: calendar))
    }

    private func date(_ isoDate: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        guard let date = formatter.date(from: isoDate) else {
            XCTFail("Invalid test fixture date: \(isoDate)")
            return Date(timeIntervalSince1970: 0)
        }

        return date
    }
}
