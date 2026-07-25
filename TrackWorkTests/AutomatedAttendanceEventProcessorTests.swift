import SwiftData
import XCTest

@testable import TrackWork

@MainActor
final class AutomatedAttendanceEventProcessorTests: XCTestCase {
    func testOfficeVisitCreatesAttendanceAndCompletesMatchingPlan() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let visitDate = day("2026-07-06")
        let plan = PlannedOfficeDay(date: visitDate)
        let entry = event(.entered, at: instant("2026-07-06T09:00:00Z"), region: "office-a")
        let exit = event(.exited, at: instant("2026-07-06T12:00:00Z"), region: "office-a")
        context.insert(ComplianceRule(minimumOfficeMinutes: 180, effectiveFrom: visitDate))
        context.insert(plan)
        context.insert(entry)
        context.insert(exit)
        try context.save()

        try AutomatedAttendanceEventProcessor(calendar: calendar)
            .recalculateAttendance(affectedBy: exit, in: context)
        try context.save()

        let attendanceDay = try XCTUnwrap(try context.fetch(FetchDescriptor<AttendanceDay>()).first)
        XCTAssertEqual(attendanceDay.date, visitDate)
        XCTAssertEqual(attendanceDay.officeMinutes, 180)
        XCTAssertEqual(attendanceDay.detectedClassification, .office)
        XCTAssertEqual(attendanceDay.finalClassification, .office)
        XCTAssertEqual(attendanceDay.complianceTreatment, .countsAsOffice)
        XCTAssertTrue(try context.fetch(FetchDescriptor<PlannedOfficeDay>()).isEmpty)
    }

    func testAutomatedVisitPreservesManualFinalStatus() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let visitDate = day("2026-07-06")
        let attendanceDay = AttendanceDay(
            date: visitDate,
            finalClassification: .home,
            manualClassification: .home,
            complianceTreatment: .countsAsHome
        )
        let plan = PlannedOfficeDay(date: visitDate)
        let entry = event(.entered, at: instant("2026-07-06T09:00:00Z"), region: "office-a")
        let exit = event(.exited, at: instant("2026-07-06T13:00:00Z"), region: "office-a")
        context.insert(attendanceDay)
        context.insert(plan)
        context.insert(entry)
        context.insert(exit)
        context.insert(ComplianceRule(minimumOfficeMinutes: 180, effectiveFrom: visitDate))
        try context.save()

        try AutomatedAttendanceEventProcessor(calendar: calendar)
            .recalculateAttendance(affectedBy: exit, in: context)
        try context.save()

        XCTAssertEqual(attendanceDay.officeMinutes, 240)
        XCTAssertEqual(attendanceDay.detectedClassification, .office)
        XCTAssertEqual(attendanceDay.manualClassification, .home)
        XCTAssertEqual(attendanceDay.finalClassification, .home)
        XCTAssertEqual(attendanceDay.complianceTreatment, .countsAsHome)
        XCTAssertEqual(try context.fetch(FetchDescriptor<PlannedOfficeDay>()).count, 1)
    }

    func testPublicHolidayBeatsLeaveCustomExclusionAndManualStatus() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let visitDate = day("2026-07-06")
        let attendanceDay = AttendanceDay(
            date: visitDate,
            finalClassification: .office,
            manualClassification: .office,
            complianceTreatment: .countsAsOffice
        )
        let entry = event(.entered, at: instant("2026-07-06T09:00:00Z"), region: "office-a")
        let exit = event(.exited, at: instant("2026-07-06T13:00:00Z"), region: "office-a")
        context.insert(attendanceDay)
        context.insert(entry)
        context.insert(exit)
        context.insert(ComplianceRule(jurisdictionId: "AU-VIC", effectiveFrom: visitDate))
        context.insert(LeaveRecord(date: visitDate, leaveType: .annualLeave))
        context.insert(CustomExcludedDay(date: visitDate, reason: "Closure"))
        context.insert(
            PublicHoliday(
                date: visitDate,
                name: "Test Holiday",
                country: .australia,
                jurisdictionId: "AU-VIC",
                isRegional: false,
                sourceName: "Test"
            )
        )
        try context.save()

        try AutomatedAttendanceEventProcessor(calendar: calendar)
            .recalculateAttendance(affectedBy: exit, in: context)

        XCTAssertEqual(attendanceDay.detectedClassification, .office)
        XCTAssertEqual(attendanceDay.manualClassification, .office)
        XCTAssertEqual(attendanceDay.finalClassification, .publicHoliday)
        XCTAssertEqual(attendanceDay.complianceTreatment, .excludedFromRequirement)
    }

    func testVisitResolverRejectsVisitLongerThanEighteenHours() {
        let entry = event(.entered, at: instant("2026-07-06T00:00:00Z"), region: "office-a")
        let exit = event(.exited, at: instant("2026-07-06T18:00:01Z"), region: "office-a")

        XCTAssertTrue(LocationVisitResolver().visits(from: [entry, exit]).isEmpty)
    }

    func testVisitResolverReplacesMissedExitWithNewerEntry() throws {
        let staleEntry = event(.entered, at: instant("2026-07-06T08:00:00Z"), region: "office-a")
        let repairedEntry = event(.entered, at: instant("2026-07-06T09:00:00Z"), region: "office-a")
        let exit = event(.exited, at: instant("2026-07-06T12:00:00Z"), region: "office-a")

        let visit = try XCTUnwrap(LocationVisitResolver().visits(from: [staleEntry, repairedEntry, exit]).first)
        XCTAssertEqual(visit.entryEventID, repairedEntry.id)
        XCTAssertEqual(visit.exitEventID, exit.id)
        XCTAssertEqual(visit.enteredAt, repairedEntry.occurredAt)
        XCTAssertEqual(visit.exitedAt, exit.occurredAt)
    }

    func testVisitResolverPairsSameTypeVisitsByRegionIdentifier() throws {
        let firstEntry = event(.entered, at: instant("2026-07-06T09:00:00Z"), region: "office-a")
        let secondEntry = event(.entered, at: instant("2026-07-06T09:30:00Z"), region: "office-b")
        let firstExit = event(.exited, at: instant("2026-07-06T11:00:00Z"), region: "office-a")
        let secondExit = event(.exited, at: instant("2026-07-06T12:00:00Z"), region: "office-b")

        let visits = LocationVisitResolver().visits(
            from: [firstEntry, secondEntry, firstExit, secondExit]
        )

        XCTAssertEqual(visits.count, 2)
        XCTAssertEqual(visits.map(\.regionIdentifier), ["office-a", "office-b"])
        XCTAssertEqual(visits.map(\.entryEventID), [firstEntry.id, secondEntry.id])
        XCTAssertEqual(visits.map(\.exitEventID), [firstExit.id, secondExit.id])
    }

    func testOverlapDetectionRejectsIntersectingHomeAndOfficeAreas() {
        let home = Place(
            name: "Home",
            type: .home,
            latitude: -37.8136,
            longitude: 144.9631,
            radiusMeters: 200
        )
        let office = Place(
            name: "Office",
            type: .office,
            latitude: -37.8136,
            longitude: 144.9631,
            radiusMeters: 200
        )

        XCTAssertTrue(LocationTrackingService.hasAmbiguousOverlap(in: [home, office]))
        office.latitude = -37.70
        XCTAssertFalse(LocationTrackingService.hasAmbiguousOverlap(in: [home, office]))
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            AttendanceDay.self,
            LocationEvent.self,
            LeaveRecord.self,
            PublicHoliday.self,
            CustomExcludedDay.self,
            ComplianceRule.self,
            PlannedOfficeDay.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func event(
        _ kind: LocationEventKind,
        at occurredAt: Date,
        region: String,
        placeType: PlaceType = .office
    ) -> LocationEvent {
        LocationEvent(
            placeName: placeType.displayName,
            placeType: placeType,
            eventKind: kind,
            regionIdentifier: region,
            occurredAt: occurredAt,
            createdAt: occurredAt
        )
    }

    private func day(_ value: String) -> Date {
        instant("\(value)T00:00:00Z")
    }

    private func instant(_ value: String) -> Date {
        guard let date = ISO8601DateFormatter().date(from: value) else {
            preconditionFailure("Invalid test date: \(value)")
        }
        return date
    }
}

@MainActor
final class LocationTrackingPersistenceTests: XCTestCase {
    func testQueuedBoundaryEventFlushesAfterModelContextConfiguration() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let fixture = makeTrackingService()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let occurredAt = instant("2026-07-06T09:00:00Z")

        fixture.service.recordBoundaryEvent(
            regionIdentifier: regionIdentifier,
            kind: .entered,
            occurredAt: occurredAt
        )
        XCTAssertTrue(try context.fetch(FetchDescriptor<LocationEvent>()).isEmpty)

        fixture.service.configure(modelContext: context)

        let events = try context.fetch(FetchDescriptor<LocationEvent>())
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.eventKind, .entered)
        XCTAssertEqual(events.first?.occurredAt, occurredAt)
        XCTAssertEqual(try context.fetch(FetchDescriptor<AttendanceDay>()).count, 1)
    }

    func testBoundaryEventDeduplicatesWithinSixtySecondWindow() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let fixture = makeTrackingService()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        fixture.service.configure(modelContext: context)
        let occurredAt = instant("2026-07-06T09:00:00Z")

        fixture.service.recordBoundaryEvent(
            regionIdentifier: regionIdentifier,
            kind: .entered,
            occurredAt: occurredAt
        )
        fixture.service.recordBoundaryEvent(
            regionIdentifier: regionIdentifier,
            kind: .entered,
            occurredAt: occurredAt.addingTimeInterval(59)
        )
        XCTAssertEqual(try context.fetch(FetchDescriptor<LocationEvent>()).count, 1)

        fixture.service.recordBoundaryEvent(
            regionIdentifier: regionIdentifier,
            kind: .entered,
            occurredAt: occurredAt.addingTimeInterval(61)
        )
        XCTAssertEqual(try context.fetch(FetchDescriptor<LocationEvent>()).count, 2)
    }

    func testDisablingAutomationClosesPersistedOpenVisit() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let fixture = makeTrackingService()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let entry = LocationEvent(
            placeName: "Office",
            placeType: .office,
            eventKind: .entered,
            regionIdentifier: regionIdentifier,
            occurredAt: .now.addingTimeInterval(-60)
        )
        context.insert(entry)
        try context.save()
        fixture.service.configure(modelContext: context)

        XCTAssertTrue(fixture.service.setAutomaticTrackingEnabled(false, for: []))

        let events = try context.fetch(FetchDescriptor<LocationEvent>())
        XCTAssertEqual(events.count, 2)
        XCTAssertTrue(LocationVisitResolver().openEntries(from: events).isEmpty)
        XCTAssertTrue(events.contains(where: { $0.eventKind == .exited }))
    }

    private var regionIdentifier: String {
        "worktrack.place.office.00000000-0000-0000-0000-000000000707"
    }

    private func makeTrackingService() -> TrackingServiceFixture {
        let suiteName = "LocationTrackingPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        let service = LocationTrackingService(
            defaults: defaults,
            automationPreferenceKey: "test.automation",
            automaticBackgroundTrackingEnabled: true,
            isUITesting: false
        )
        return TrackingServiceFixture(service: service, defaults: defaults, suiteName: suiteName)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            AttendanceDay.self,
            LocationEvent.self,
            LeaveRecord.self,
            PublicHoliday.self,
            CustomExcludedDay.self,
            ComplianceRule.self,
            PlannedOfficeDay.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func instant(_ value: String) -> Date {
        guard let date = ISO8601DateFormatter().date(from: value) else {
            preconditionFailure("Invalid test date: \(value)")
        }
        return date
    }
}

private struct TrackingServiceFixture {
    let service: LocationTrackingService
    let defaults: UserDefaults
    let suiteName: String
}
