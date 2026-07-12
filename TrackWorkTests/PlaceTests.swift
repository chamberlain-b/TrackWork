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
            formattedAddress: "1 Collins Street, Melbourne VIC 3000, Australia",
            radiusMeters: 200
        )

        context.insert(home)
        context.insert(office)
        try context.save()

        let descriptor = FetchDescriptor<Place>(sortBy: [SortDescriptor(\Place.typeRaw)])
        let persistedPlaces = try context.fetch(descriptor)

        XCTAssertEqual(persistedPlaces.count, 2)
        let persistedHome = try XCTUnwrap(persistedPlaces.first { $0.type == .home })
        let persistedOffice = try XCTUnwrap(persistedPlaces.first { $0.type == .office })

        XCTAssertEqual(persistedHome.radiusMeters, 150)
        XCTAssertNil(persistedHome.formattedAddress)
        XCTAssertEqual(persistedHome.displayAddress, "Map-selected location")
        XCTAssertEqual(persistedOffice.name, "Office")
        XCTAssertEqual(persistedOffice.formattedAddress, "1 Collins Street, Melbourne VIC 3000, Australia")
        XCTAssertEqual(persistedOffice.displayAddress, "1 Collins Street, Melbourne VIC 3000, Australia")
    }

    func testDisplayAddressTrimsSavedAddressAndFallsBackForMissingValues() {
        let addressedPlace = Place(
            name: "Office",
            type: .office,
            latitude: -37.8183,
            longitude: 144.9671,
            formattedAddress: "  1 Collins Street, Melbourne VIC 3000, Australia  "
        )
        let emptyAddressPlace = Place(
            name: "Home",
            type: .home,
            latitude: -37.8136,
            longitude: 144.9631,
            formattedAddress: "  \n  "
        )
        let missingAddressPlace = Place(
            name: "Home",
            type: .home,
            latitude: -37.8136,
            longitude: 144.9631
        )

        XCTAssertEqual(addressedPlace.displayAddress, "1 Collins Street, Melbourne VIC 3000, Australia")
        XCTAssertEqual(emptyAddressPlace.displayAddress, "Map-selected location")
        XCTAssertEqual(missingAddressPlace.displayAddress, "Map-selected location")
    }

    func testPlaceSelectionRoundTripsPlaceLocationAndAddress() {
        let place = Place(
            name: "Office",
            type: .office,
            latitude: -37.8183,
            longitude: 144.9671,
            formattedAddress: "1 Collins Street, Melbourne VIC 3000, Australia",
            radiusMeters: 200
        )

        let selection = PlaceSelection(place: place)

        XCTAssertEqual(selection.latitude, place.latitude)
        XCTAssertEqual(selection.longitude, place.longitude)
        XCTAssertEqual(selection.coordinate.latitude, place.latitude)
        XCTAssertEqual(selection.coordinate.longitude, place.longitude)
        XCTAssertEqual(selection.formattedAddress, place.displayAddress)

        let restoredPlace = Place(
            name: place.name,
            type: .office,
            latitude: selection.latitude,
            longitude: selection.longitude,
            formattedAddress: selection.formattedAddress,
            radiusMeters: place.radiusMeters
        )

        XCTAssertEqual(PlaceSelection(place: restoredPlace), selection)
    }
}
