import CoreLocation
import SwiftData
import XCTest
@testable import TrackWork

final class LocationEventTests: XCTestCase {
    @MainActor
    func testLocationEventsPersistDerivedEnterExitRecords() throws {
        let schema = Schema([Place.self, LocationEvent.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let placeId = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
        let occurredAt = Date(timeIntervalSince1970: 1_783_036_800)

        let event = LocationEvent(
            placeId: placeId,
            placeName: "Office",
            placeType: .office,
            eventKind: .entered,
            regionIdentifier: "worktrack.place.office.\(placeId.uuidString)",
            occurredAt: occurredAt,
            createdAt: occurredAt
        )

        context.insert(event)
        try context.save()

        let descriptor = FetchDescriptor<LocationEvent>(sortBy: [SortDescriptor(\LocationEvent.occurredAt)])
        let persistedEvents = try context.fetch(descriptor)

        XCTAssertEqual(persistedEvents.count, 1)
        XCTAssertEqual(persistedEvents[0].placeId, placeId)
        XCTAssertEqual(persistedEvents[0].placeType, .office)
        XCTAssertEqual(persistedEvents[0].eventKind, .entered)
        XCTAssertEqual(persistedEvents[0].regionIdentifier, "worktrack.place.office.\(placeId.uuidString)")
    }

    func testGeofenceRegionUsesPlaceMetadataAndCapsRadius() {
        let placeId = UUID(uuidString: "00000000-0000-0000-0000-000000000202")!
        let place = Place(
            id: placeId,
            name: "Home",
            type: .home,
            latitude: -37.8136,
            longitude: 144.9631,
            radiusMeters: 500
        )

        let region = LocationTrackingService.makeRegion(for: place, maximumMonitoringDistance: 150)

        XCTAssertNotNil(region)
        XCTAssertEqual(region?.identifier, "worktrack.place.home.\(placeId.uuidString)")
        XCTAssertEqual(region?.center.latitude, -37.8136, accuracy: 0.000001)
        XCTAssertEqual(region?.center.longitude, 144.9631, accuracy: 0.000001)
        XCTAssertEqual(region?.radius, 150)
        XCTAssertTrue(region?.notifyOnEntry ?? false)
        XCTAssertTrue(region?.notifyOnExit ?? false)
        XCTAssertEqual(LocationTrackingService.placeType(from: region?.identifier ?? ""), .home)
        XCTAssertEqual(LocationTrackingService.placeId(from: region?.identifier ?? ""), placeId)
    }
}
