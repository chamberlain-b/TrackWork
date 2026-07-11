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

    @MainActor
    func testGeofenceRegionUsesPlaceMetadataAndCapsRadius() throws {
        let placeId = UUID(uuidString: "00000000-0000-0000-0000-000000000202")!
        let place = Place(
            id: placeId,
            name: "Home",
            type: .home,
            latitude: -37.8136,
            longitude: 144.9631,
            radiusMeters: 500
        )

        let region = try XCTUnwrap(
            LocationTrackingService.makeRegion(for: place, maximumMonitoringDistance: 150)
        )

        XCTAssertEqual(region.identifier, "worktrack.place.home.\(placeId.uuidString)")
        XCTAssertEqual(region.center.latitude, -37.8136, accuracy: 0.000001)
        XCTAssertEqual(region.center.longitude, 144.9631, accuracy: 0.000001)
        XCTAssertEqual(region.radius, 150)
        XCTAssertTrue(region.notifyOnEntry)
        XCTAssertTrue(region.notifyOnExit)
        XCTAssertEqual(LocationTrackingService.placeType(from: region.identifier), .home)
        XCTAssertEqual(LocationTrackingService.placeId(from: region.identifier), placeId)
    }

    func testActiveHolidayResolverDoesNotLeakAnotherJurisdiction() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 10))
        )
        let victoriaHoliday = PublicHoliday(
            date: date,
            name: "Victorian Holiday",
            country: .australia,
            jurisdictionId: "AU-VIC",
            isRegional: true,
            sourceName: "Victoria"
        )
        let newSouthWalesHoliday = PublicHoliday(
            date: date,
            name: "NSW Holiday",
            country: .australia,
            jurisdictionId: "AU-NSW",
            isRegional: true,
            sourceName: "New South Wales"
        )

        let activeHoliday = ActiveJurisdictionHolidayResolver.holiday(
            on: date,
            from: [newSouthWalesHoliday, victoriaHoliday],
            jurisdictionId: "AU-VIC",
            calendar: calendar
        )

        XCTAssertEqual(activeHoliday?.name, "Victorian Holiday")
        XCTAssertEqual(activeHoliday?.jurisdictionId, "AU-VIC")
    }

    func testCalendarDayAccessibilityIdentifierUsesStableISODate() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Australia/Melbourne")!
        let date = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 11, hour: 23, minute: 45))
        )

        XCTAssertEqual(
            calendar.calendarDayAccessibilityIdentifier(for: date),
            "calendar.day.2026-07-11"
        )
    }
}
