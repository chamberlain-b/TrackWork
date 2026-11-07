import CoreLocation
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

    func testConfirmedInsideUpdatesBeforeDepartureAndDoesNotDoubleCountLaterExit() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let processor = AutomatedAttendanceEventProcessor(calendar: calendar)
        let entry = event(.entered, at: instant("2026-07-06T09:00:00Z"), region: "office-a")
        let confirmation = event(.confirmedInside, at: instant("2026-07-06T12:00:00Z"), region: "office-a")
        context.insert(ComplianceRule(minimumOfficeMinutes: 180, effectiveFrom: day("2026-07-06")))
        context.insert(entry)
        context.insert(confirmation)
        try processor.recalculateAttendance(affectedBy: confirmation, in: context)
        try context.save()
        let attendance = try XCTUnwrap(try context.fetch(FetchDescriptor<AttendanceDay>()).first)
        XCTAssertEqual(attendance.officeMinutes, 180)
        XCTAssertEqual(attendance.finalClassification, .office)
        XCTAssertEqual(LocationVisitResolver().openEntries(from: [entry, confirmation]).first?.id, entry.id)

        let exit = event(.exited, at: instant("2026-07-06T13:00:00Z"), region: "office-a")
        context.insert(exit)
        try processor.recalculateAttendance(affectedBy: exit, in: context)
        try context.save()
        XCTAssertEqual(attendance.officeMinutes, 240)
        XCTAssertEqual(try context.fetch(FetchDescriptor<AttendanceDay>()).count, 1)
    }

    func testRepeatedInsideConfirmationsPreserveEntryAndOnlyCountThroughLatestEvidence() throws {
        let entry = event(.entered, at: instant("2026-07-06T09:00:00Z"), region: "office-a")
        let first = event(.confirmedInside, at: instant("2026-07-06T10:00:00Z"), region: "office-a")
        let latest = event(.confirmedInside, at: instant("2026-07-06T12:00:00Z"), region: "office-a")
        let events = [latest, entry, first, latest]
        let visits = LocationVisitResolver().visits(from: events)
        let visit = try XCTUnwrap(visits.first)
        XCTAssertEqual(visits.count, 1)
        XCTAssertEqual(visit.enteredAt, entry.occurredAt)
        XCTAssertEqual(visit.exitedAt, latest.occurredAt)
        XCTAssertEqual(LocationVisitResolver().openEntries(from: events).count, 1)
    }

    func testOutsideConfirmationKeepsConfirmedTimeWithoutGuessingDeparture() throws {
        let entry = event(.entered, at: instant("2026-07-06T09:00:00Z"), region: "office-a")
        let inside = event(.confirmedInside, at: instant("2026-07-06T12:00:00Z"), region: "office-a")
        let outside = event(.confirmedOutside, at: instant("2026-07-06T17:00:00Z"), region: "office-a")
        let events = [outside, entry, inside]
        XCTAssertEqual(LocationVisitResolver().visits(from: events).first?.exitedAt, inside.occurredAt)
        XCTAssertTrue(LocationVisitResolver().openEntries(from: events).isEmpty)
        XCTAssertTrue(LocationVisitResolver().visits(from: [entry, outside]).isEmpty)
    }

    func testStaleInsideObservationStartsFreshAndKeepsOnlyEarlierConfirmedTime() throws {
        let entry = event(.entered, at: instant("2026-07-06T09:00:00Z"), region: "office-a")
        let inside = event(.confirmedInside, at: instant("2026-07-06T12:00:00Z"), region: "office-a")
        let nextDay = event(.confirmedInside, at: instant("2026-07-07T09:00:00Z"), region: "office-a")
        let resolver = LocationVisitResolver()
        XCTAssertTrue(resolver.visits(from: [entry, nextDay]).isEmpty)
        XCTAssertEqual(resolver.openEntries(from: [entry, nextDay]).first?.id, nextDay.id)
        let visits = resolver.visits(from: [entry, inside, nextDay])
        XCTAssertEqual(visits.count, 1)
        XCTAssertEqual(visits.first?.exitedAt, inside.occurredAt)
    }

    func testNewEntryKeepsConfirmedPrefixWithoutBridgingMissedExit() {
        let first = event(.entered, at: instant("2026-07-06T09:00:00Z"), region: "office-a")
        let inside = event(.confirmedInside, at: instant("2026-07-06T10:00:00Z"), region: "office-a")
        let second = event(.entered, at: instant("2026-07-06T12:00:00Z"), region: "office-a")
        let exit = event(.exited, at: instant("2026-07-06T13:00:00Z"), region: "office-a")
        let visits = LocationVisitResolver().visits(from: [exit, second, inside, first])
        XCTAssertEqual(visits.map { Int($0.exitedAt.timeIntervalSince($0.enteredAt) / 60) }, [60, 60])
    }

    func testPairedStateAndBoundaryCallbacksResolveInEitherCallbackOrder() throws {
        for stateFirst in [true, false] {
            let entryTime = instant("2026-07-06T09:00:00Z")
            let exitTime = instant("2026-07-06T12:00:00Z")
            let entry = event(.entered, at: entryTime, region: "office-a")
            let inside = event(.confirmedInside, at: entryTime.addingTimeInterval(stateFirst ? -0.1 : 0.1), region: "office-a")
            let exit = event(.exited, at: exitTime, region: "office-a")
            let outside = event(.confirmedOutside, at: exitTime.addingTimeInterval(stateFirst ? -0.1 : 0.1), region: "office-a")
            let events = [outside, inside, exit, entry]
            let visits = LocationVisitResolver().visits(from: events)
            XCTAssertEqual(visits.count, 1)
            XCTAssertEqual(visits.first?.enteredAt, entryTime)
            XCTAssertEqual(visits.first?.exitedAt, exitTime)
            XCTAssertTrue(LocationVisitResolver().openEntries(from: events).isEmpty)
        }
    }

    func testContraryStateObservationIsNeverSuppressedByNearbyBoundary() {
        let entry = event(.entered, at: instant("2026-07-06T09:00:00Z"), region: "office-a")
        let outside = event(.confirmedOutside, at: instant("2026-07-06T09:00:02Z"), region: "office-a")
        let inside = event(.confirmedInside, at: instant("2026-07-06T12:00:00Z"), region: "office-a")
        let events = [entry, outside, inside]
        XCTAssertTrue(LocationVisitResolver().visits(from: events).isEmpty)
        XCTAssertEqual(LocationVisitResolver().openEntries(from: events).first?.id, inside.id)

        let exit = event(.exited, at: instant("2026-07-06T13:00:00Z"), region: "office-a")
        let returnInside = event(.confirmedInside, at: instant("2026-07-06T13:00:02Z"), region: "office-a")
        XCTAssertEqual(LocationVisitResolver().openEntries(from: events + [exit, returnInside]).first?.id, returnInside.id)
    }

    func testLateEntryRecalculatesPreviouslyPairedDayAcrossMidnight() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let processor = AutomatedAttendanceEventProcessor(calendar: calendar)
        let entry = event(.entered, at: instant("2026-07-06T23:00:00Z"), region: "office-a")
        let exit = event(.exited, at: instant("2026-07-07T03:00:00Z"), region: "office-a")
        context.insert(entry)
        context.insert(exit)
        try processor.recalculateAttendance(affectedBy: exit, in: context)
        try context.save()
        let lateEntry = event(.entered, at: instant("2026-07-07T01:00:00Z"), region: "office-a")
        context.insert(lateEntry)
        try processor.recalculateAttendance(affectedBy: lateEntry, in: context)
        try context.save()
        let days = try context.fetch(FetchDescriptor<AttendanceDay>()).sorted { $0.date < $1.date }
        XCTAssertEqual(days.count, 2)
        XCTAssertEqual(days.map(\.officeMinutes), [0, 120])
    }

    func testInsideConfirmationAllocatesElapsedMinutesAcrossLocalMidnight() throws {
        var localCalendar = calendar
        localCalendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Australia/Melbourne"))
        let entry = event(.entered, at: instant("2026-07-06T13:00:00Z"), region: "office-a")
        let inside = event(.confirmedInside, at: instant("2026-07-06T16:00:00Z"), region: "office-a")
        let inferences = AttendanceInferenceService(calendar: localCalendar).inferDailyAttendance(
            from: [entry, inside], periodStart: entry.occurredAt, periodEnd: inside.occurredAt
        )
        XCTAssertEqual(inferences.map(\.officeMinutes), [60, 120])
    }

    func testConfirmedVisitPreservesManualLeaveAndExclusionPrecedence() throws {
        for protection in ["manual", "leave", "excluded"] {
            let container = try makeContainer()
            let context = container.mainContext
            let date = day("2026-07-06")
            let attendance = AttendanceDay(date: date, finalClassification: .home, manualClassification: .home)
            context.insert(attendance)
            context.insert(event(.entered, at: instant("2026-07-06T09:00:00Z"), region: "office-a"))
            let inside = event(.confirmedInside, at: instant("2026-07-06T12:00:00Z"), region: "office-a")
            context.insert(inside)
            if protection == "leave" { context.insert(LeaveRecord(date: date, leaveType: .sickLeave)) }
            if protection == "excluded" { context.insert(CustomExcludedDay(date: date, reason: "Closure")) }
            try AutomatedAttendanceEventProcessor(calendar: calendar).recalculateAttendance(affectedBy: inside, in: context)
            XCTAssertEqual(attendance.officeMinutes, 180)
            XCTAssertEqual(attendance.detectedClassification, .office)
            XCTAssertEqual(attendance.manualClassification, .home)
            let expected: AttendanceClassification = protection == "manual" ? .home : protection == "leave" ? .sickLeave : .nonWorkingDay
            XCTAssertEqual(attendance.finalClassification, expected)
        }
    }

    func testForegroundConfirmationSchedulesThresholdThenOnlyDayRollover() throws {
        let now = instant("2026-07-06T11:59:00Z")
        let events = [
            event(.entered, at: instant("2026-07-06T09:00:00Z"), region: "office-a"),
            event(.confirmedInside, at: now, region: "office-a")
        ]
        let attendance = AttendanceDay(date: day("2026-07-06"), officeMinutes: 179)
        let threshold = LocationTrackingService.nextForegroundConfirmation(
            after: now, events: events, attendanceDays: [attendance], rules: [], calendar: calendar
        )
        XCTAssertEqual(threshold, instant("2026-07-06T12:00:00Z"))
        attendance.officeMinutes = 180
        XCTAssertEqual(LocationTrackingService.nextForegroundConfirmation(
            after: now, events: events, attendanceDays: [attendance], rules: [], calendar: calendar
        ), day("2026-07-07"))
        XCTAssertNil(LocationTrackingService.nextForegroundConfirmation(
            after: now, events: [], attendanceDays: [], rules: [], calendar: calendar
        ))
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
        XCTAssertTrue(events.contains(where: { $0.eventKind == .monitoringStopped }))
        XCTAssertEqual(LocationEventKind.monitoringStopped.displayName, "Monitoring stopped")
        XCTAssertTrue(try context.fetch(FetchDescriptor<AttendanceDay>()).isEmpty)
    }

    func testForegroundStateEvidenceSavesImmediatelyAndDoesNotDebounceThresholdCrossing() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let fixture = makeTrackingService()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        fixture.service.configure(modelContext: context)
        fixture.service.recordBoundaryEvent(regionIdentifier: regionIdentifier, kind: .entered,
                                            occurredAt: instant("2026-07-06T09:00:00Z"))
        fixture.service.recordRegionState(.inside, regionIdentifier: regionIdentifier,
                                          occurredAt: instant("2026-07-06T11:59:30Z"))
        let attendance = try XCTUnwrap(try context.fetch(FetchDescriptor<AttendanceDay>()).first)
        XCTAssertEqual(attendance.officeMinutes, 179)
        XCTAssertEqual(attendance.finalClassification, .unknown)
        fixture.service.recordRegionState(.inside, regionIdentifier: regionIdentifier,
                                          occurredAt: instant("2026-07-06T12:00:00Z"))
        fixture.service.recordRegionState(.inside, regionIdentifier: regionIdentifier,
                                          occurredAt: instant("2026-07-06T12:00:00Z"))
        XCTAssertEqual(attendance.officeMinutes, 180)
        XCTAssertEqual(attendance.finalClassification, .office)
        XCTAssertEqual(try context.fetch(FetchDescriptor<LocationEvent>()).count, 3)
        XCTAssertEqual(try context.fetch(FetchDescriptor<AttendanceDay>()).count, 1)
        XCTAssertFalse(context.hasChanges)
    }

    func testUnknownForegroundStateDoesNotInventAttendance() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let fixture = makeTrackingService()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        fixture.service.configure(modelContext: context)
        fixture.service.recordRegionState(.unknown, regionIdentifier: regionIdentifier,
                                          occurredAt: instant("2026-07-06T12:00:00Z"))
        XCTAssertTrue(try context.fetch(FetchDescriptor<LocationEvent>()).isEmpty)
        fixture.service.recordRegionState(.outside, regionIdentifier: regionIdentifier,
                                          occurredAt: instant("2026-07-06T12:01:00Z"))
        XCTAssertEqual(try context.fetch(FetchDescriptor<LocationEvent>()).count, 1)
        XCTAssertTrue(try context.fetch(FetchDescriptor<AttendanceDay>()).isEmpty)
    }

    func testOutsideEvidenceArrivingBeforeItsEntryStillPreventsBridgingUnknownGap() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let fixture = makeTrackingService()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        fixture.service.configure(modelContext: context)
        fixture.service.recordRegionState(.outside, regionIdentifier: regionIdentifier,
                                          occurredAt: instant("2026-07-06T12:00:00Z"))
        fixture.service.recordBoundaryEvent(regionIdentifier: regionIdentifier, kind: .entered,
                                            occurredAt: instant("2026-07-06T09:00:00Z"))
        fixture.service.recordRegionState(.inside, regionIdentifier: regionIdentifier,
                                          occurredAt: instant("2026-07-06T15:00:00Z"))
        let attendance = try XCTUnwrap(try context.fetch(FetchDescriptor<AttendanceDay>()).first)
        XCTAssertEqual(attendance.officeMinutes, 0)
        XCTAssertEqual(attendance.finalClassification, .unknown)
        fixture.service.recordRegionState(.inside, regionIdentifier: regionIdentifier,
                                          occurredAt: instant("2026-07-06T16:00:00Z"))
        XCTAssertEqual(attendance.officeMinutes, 60)
        XCTAssertEqual(try context.fetch(FetchDescriptor<AttendanceDay>()).count, 1)
    }

    func testRepeatedMonitoringStopsWithinSixtySecondsCloseEachNewObservation() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let fixture = makeTrackingService()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        fixture.service.configure(modelContext: context)
        fixture.service.recordBoundaryEvent(regionIdentifier: regionIdentifier, kind: .entered,
                                            occurredAt: instant("2026-07-06T09:00:00Z"))
        fixture.service.recordBoundaryEvent(regionIdentifier: regionIdentifier, kind: .monitoringStopped,
                                            occurredAt: instant("2026-07-06T10:00:00Z"))
        // Enabling monitoring again yields a fresh state, not a boundary crossing.
        fixture.service.recordRegionState(.inside, regionIdentifier: regionIdentifier,
                                          occurredAt: instant("2026-07-06T10:00:20Z"))
        fixture.service.recordBoundaryEvent(regionIdentifier: regionIdentifier, kind: .monitoringStopped,
                                            occurredAt: instant("2026-07-06T10:00:40Z"))
        let events = try context.fetch(FetchDescriptor<LocationEvent>())
        XCTAssertEqual(events.filter { $0.eventKind == .monitoringStopped }.count, 2)
        XCTAssertTrue(LocationVisitResolver().openEntries(from: events).isEmpty)
        fixture.service.recordRegionState(.inside, regionIdentifier: regionIdentifier,
                                          occurredAt: instant("2026-07-06T13:00:00Z"))
        let attendance = try XCTUnwrap(try context.fetch(FetchDescriptor<AttendanceDay>()).first)
        XCTAssertEqual(attendance.officeMinutes, 0)
        fixture.service.recordRegionState(.inside, regionIdentifier: regionIdentifier,
                                          occurredAt: instant("2026-07-06T14:00:00Z"))
        XCTAssertEqual(attendance.officeMinutes, 60)
    }

    private var regionIdentifier: String {
        "worktrack.place.office.00000000-0000-0000-0000-000000000707"
    }

    private func makeTrackingService() -> TrackingServiceFixture {
        let suiteName = "LocationTrackingPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let service = LocationTrackingService(
            defaults: defaults,
            calendar: calendar,
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

@MainActor
final class AutomaticAttendanceAccessPresentationTests: XCTestCase {
    func testUnrequestedAccessDoesNotClaimPermissionWasDenied() {
        let presentation = AutomaticAttendanceAccessPresentation(status: .notDetermined)

        XCTAssertEqual(presentation.title, "Not requested")
        XCTAssertTrue(presentation.detail.contains("when you choose"))
        XCTAssertFalse(presentation.detail.localizedCaseInsensitiveContains("denied"))
    }

    func testDeniedAccessExplainsSettingsRecoveryAndManualFallback() {
        let presentation = AutomaticAttendanceAccessPresentation(status: .denied)

        XCTAssertEqual(presentation.title, "Denied")
        XCTAssertTrue(presentation.detail.contains("iOS Settings"))
        XCTAssertTrue(presentation.detail.contains("manually"))
    }

    func testRestrictedAccessExplainsManualFallbackWithoutPromisingSettingsRecovery() {
        let presentation = AutomaticAttendanceAccessPresentation(status: .restricted)

        XCTAssertEqual(presentation.title, "Restricted")
        XCTAssertTrue(presentation.detail.contains("unavailable"))
        XCTAssertTrue(presentation.detail.contains("manual attendance still works"))
        XCTAssertFalse(presentation.detail.contains("Settings"))
    }

    func testWhileUsingAccessExplainsWhyAlwaysIsNeededForBackgroundAttendance() {
        let presentation = AutomaticAttendanceAccessPresentation(status: .authorizedWhenInUse)

        XCTAssertEqual(presentation.title, "While Using App")
        XCTAssertTrue(presentation.detail.contains("Always access"))
        XCTAssertTrue(presentation.detail.contains("when TrackWork is closed"))
        XCTAssertNotEqual(
            presentation.title,
            AutomaticAttendanceAccessPresentation(status: .authorizedAlways).title
        )
    }

    func testAlwaysAccessDoesNotImplyAutomaticAttendanceHasBeenEnabled() {
        let presentation = AutomaticAttendanceAccessPresentation(status: .authorizedAlways)

        XCTAssertEqual(presentation.title, "Always")
        XCTAssertTrue(presentation.detail.contains("access is allowed"))
        XCTAssertTrue(presentation.detail.contains("only while Automatic Attendance is on"))
    }
}
