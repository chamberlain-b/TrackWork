import SwiftData
import XCTest
@testable import TrackWork

@MainActor
final class CustomExcludedDayTests: XCTestCase {
    func testCustomExcludedDayPersistsLocallyWithOptionalReason() throws {
        let schema = Schema([CustomExcludedDay.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let excludedDay = CustomExcludedDay(
            date: Date(timeIntervalSince1970: 1_783_382_400),
            reason: "  Company closure  "
        )

        context.insert(excludedDay)
        try context.save()

        let storedDays = try context.fetch(FetchDescriptor<CustomExcludedDay>())
        XCTAssertEqual(storedDays.count, 1)
        XCTAssertEqual(storedDays.first?.reason, "Company closure")
    }
}
