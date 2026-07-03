import SwiftData
import XCTest
@testable import TrackWork

final class PlaceTests: XCTestCase {
    func testPlaceTypeMetadataIsStable() {
        XCTAssertEqual(PlaceType.home.rawValue, "home")
        XCTAssertEqual(PlaceType.home.displayName, "Home")
        XCTAssertEqual(PlaceType.office.rawValue, "office")
        XCTAssertEqual(PlaceType.office.displayName, "Office")
    }

    @MainActor
    func testHomeAndOfficePlacesPersistInSwiftData() throws {
        let schema = Schema([Place.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext

        let home = Place(
            name: "Home",
            type: .home,
            latitude: -37.8136,
            longitude: 144.9631,
            radiusMeters: 150
        )
        let office = Place(
            name: "Office",
            type: .office,
            latitude: -37.8183,
            longitude: 144.9671,
            radiusMeters: 200
        )

        context.insert(home)
        context.insert(office)
        try context.save()

        let descriptor = FetchDescriptor<Place>(sortBy: [SortDescriptor(\Place.typeRaw)])
        let persistedPlaces = try context.fetch(descriptor)

        XCTAssertEqual(persistedPlaces.count, 2)
        XCTAssertEqual(persistedPlaces.first { $0.type == .home }?.radiusMeters, 150)
        XCTAssertEqual(persistedPlaces.first { $0.type == .office }?.name, "Office")
    }
}
