import SwiftData
import XCTest

@testable import TrackWork

@MainActor
final class PortableBackupServiceTests: XCTestCase {
  func testStandardBackupIsDeterministicAndExcludesSensitiveLocationData() throws {
    let container = try makeContainer()
    try seedCompleteStore(container.mainContext)
    let service = PortableBackupService()

    let firstData = try service.makeBackupData(from: container.mainContext)
    let secondData = try service.makeBackupData(from: container.mainContext)
    let inspection = try service.inspect(firstData)
    let json = try XCTUnwrap(String(data: firstData, encoding: .utf8))

    XCTAssertEqual(firstData, secondData)
    XCTAssertEqual(inspection.formatVersion, 1)
    XCTAssertEqual(inspection.privacyScope, .standard)
    XCTAssertEqual(inspection.recordCounts.attendanceDays, 1)
    XCTAssertEqual(inspection.recordCounts.leaveRecords, 1)
    XCTAssertEqual(inspection.recordCounts.manualAdjustments, 1)
    XCTAssertEqual(inspection.recordCounts.complianceRules, 1)
    XCTAssertEqual(inspection.recordCounts.customExcludedDays, 1)
    XCTAssertEqual(inspection.recordCounts.plannedOfficeDays, 1)
    XCTAssertEqual(inspection.recordCounts.userEditedHolidays, 1)
    XCTAssertEqual(inspection.recordCounts.places, 0)
    XCTAssertEqual(inspection.recordCounts.locationEvents, 0)
    XCTAssertFalse(json.contains("latitude"))
    XCTAssertFalse(json.contains("Private office address"))
    XCTAssertFalse(json.contains("worktrack.private.office"))
  }

  func testFullPrivateReplaceRoundTripsAllUserOwnedRecordsAndPreservesBundledHolidays() throws {
    let sourceContainer = try makeContainer()
    try seedCompleteStore(sourceContainer.mainContext)
    let service = PortableBackupService()
    let sourceData = try service.makeBackupData(
      from: sourceContainer.mainContext,
      privacyScope: .fullPrivate
    )

    let destinationContainer = try makeContainer()
    let destinationContext = destinationContainer.mainContext
    let fixture = try seedReplacementDestination(destinationContext)

    let result = try service.restore(sourceData, policy: .replace, into: destinationContext)
    let restoredData = try service.makeBackupData(
      from: destinationContext,
      privacyScope: .fullPrivate
    )

    XCTAssertEqual(result.policy, .replace)
    XCTAssertEqual(result.privacyScope, .fullPrivate)
    XCTAssertEqual(result.recordCounts.total, 9)
    XCTAssertEqual(restoredData, sourceData)
    XCTAssertTrue(
      try fetch(AttendanceDay.self, from: destinationContext).allSatisfy {
        $0.id != fixture.staleAttendanceID
      })
    XCTAssertTrue(
      try fetch(Place.self, from: destinationContext).allSatisfy {
        $0.id != fixture.stalePlaceID
      })
    XCTAssertEqual(try fetch(PublicHoliday.self, from: destinationContext).count, 2)
    XCTAssertNotNil(
      try fetch(PublicHoliday.self, from: destinationContext)
        .first(where: { $0.id == fixture.bundledHolidayID && !$0.isUserEdited })
    )
  }

  func testStandardReplacePreservesLocalSensitiveLocationDomains() throws {
    let sourceContainer = try makeContainer()
    try seedCompleteStore(sourceContainer.mainContext)
    let service = PortableBackupService()
    let standardData = try service.makeBackupData(from: sourceContainer.mainContext)

    let destinationContainer = try makeContainer()
    let destinationContext = destinationContainer.mainContext
    let localPlace = Place(
      id: uuid(80),
      name: "Keep local office",
      type: .office,
      latitude: -37.81,
      longitude: 144.96,
      formattedAddress: "Keep this private"
    )
    let localEvent = LocationEvent(
      id: uuid(81),
      placeId: localPlace.id,
      placeName: localPlace.name,
      placeType: .office,
      eventKind: .entered,
      regionIdentifier: "worktrack.keep.local"
    )
    destinationContext.insert(localPlace)
    destinationContext.insert(localEvent)
    destinationContext.insert(ComplianceRule(id: uuid(82), name: "Replace me"))
    try destinationContext.save()

    _ = try service.restore(standardData, policy: .replace, into: destinationContext)

    XCTAssertEqual(try fetch(Place.self, from: destinationContext).map(\.id), [localPlace.id])
    XCTAssertEqual(
      try fetch(LocationEvent.self, from: destinationContext).map(\.id), [localEvent.id])
    XCTAssertEqual(
      try service.makeBackupData(from: destinationContext),
      standardData
    )
  }

  func testMergeLetsBackupValuesWinAndPreservesLocalOnlyRecords() throws {
    let sourceContainer = try makeContainer()
    let sourceContext = sourceContainer.mainContext
    let sharedID = uuid(70)
    sourceContext.insert(
      AttendanceDay(
        id: sharedID,
        date: date("2026-07-07"),
        finalClassification: .office,
        complianceTreatment: .countsAsOffice,
        note: "Backup wins"
      )
    )
    try sourceContext.save()
    let service = PortableBackupService()
    let sourceData = try service.makeBackupData(from: sourceContext)

    let destinationContainer = try makeContainer()
    let destinationContext = destinationContainer.mainContext
    let localOnlyID = uuid(71)
    destinationContext.insert(
      AttendanceDay(
        id: sharedID,
        date: date("2026-07-07"),
        finalClassification: .home,
        complianceTreatment: .countsAsHome,
        note: "Local loses"
      )
    )
    destinationContext.insert(
      AttendanceDay(
        id: localOnlyID,
        date: date("2026-07-08"),
        finalClassification: .home,
        complianceTreatment: .countsAsHome,
        note: "Local only"
      )
    )
    try destinationContext.save()

    _ = try service.restore(sourceData, policy: .mergePreferBackup, into: destinationContext)

    let restored = try fetch(AttendanceDay.self, from: destinationContext)
    XCTAssertEqual(restored.count, 2)
    XCTAssertEqual(restored.first(where: { $0.id == sharedID })?.note, "Backup wins")
    XCTAssertEqual(restored.first(where: { $0.id == sharedID })?.finalClassification, .office)
    XCTAssertEqual(restored.first(where: { $0.id == localOnlyID })?.note, "Local only")
  }

  func testInvalidReferencesAreRejectedBeforeCurrentStoreMutation() throws {
    let sourceContainer = try makeContainer()
    try seedCompleteStore(sourceContainer.mainContext)
    let service = PortableBackupService()
    let validData = try service.makeBackupData(from: sourceContainer.mainContext)
    let invalidData = try replacingManualAdjustmentReference(in: validData, with: uuid(99))

    let destinationContainer = try makeContainer()
    let destinationContext = destinationContainer.mainContext
    let baselineID = uuid(60)
    destinationContext.insert(
      AttendanceDay(
        id: baselineID,
        date: date("2026-05-01"),
        finalClassification: .home,
        note: "Must survive"
      )
    )
    try destinationContext.save()

    XCTAssertThrowsError(
      try service.restore(invalidData, policy: .replace, into: destinationContext)
    ) { error in
      guard case .invalidPayload = error as? PortableBackupError else {
        return XCTFail("Expected invalidPayload, received \(error)")
      }
    }

    let records = try fetch(AttendanceDay.self, from: destinationContext)
    XCTAssertEqual(records.count, 1)
    XCTAssertEqual(records.first?.id, baselineID)
    XCTAssertEqual(records.first?.note, "Must survive")
  }

  func testDuplicateManualAdjustmentRelationshipsAreRejected() throws {
    let container = try makeContainer()
    try seedCompleteStore(container.mainContext)
    let service = PortableBackupService()
    let validData = try service.makeBackupData(from: container.mainContext)

    var root = try XCTUnwrap(JSONSerialization.jsonObject(with: validData) as? [String: Any])
    var adjustments = try XCTUnwrap(root["manualAdjustments"] as? [[String: Any]])
    var duplicateAdjustment = try XCTUnwrap(adjustments.first)
    duplicateAdjustment["id"] = uuid(99).uuidString
    adjustments.append(duplicateAdjustment)
    root["manualAdjustments"] = adjustments
    let invalidData = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])

    XCTAssertThrowsError(try service.inspect(invalidData)) { error in
      XCTAssertEqual(
        error as? PortableBackupError,
        .invalidPayload("Multiple manual adjustments reference the same attendance day.")
      )
    }
  }

  func testCorruptUnsupportedAndMislabelledSensitivePayloadsAreRejected() throws {
    let container = try makeContainer()
    try seedCompleteStore(container.mainContext)
    let service = PortableBackupService()

    XCTAssertThrowsError(try service.inspect(Data("not json".utf8))) { error in
      XCTAssertEqual(error as? PortableBackupError, .corruptPayload)
    }

    let unsupported = Data(
      "{\"formatIdentifier\":\"com.benchamberlain.worktrack.portable-backup\",\"formatVersion\":99}"
        .utf8
    )
    XCTAssertThrowsError(try service.inspect(unsupported)) { error in
      XCTAssertEqual(error as? PortableBackupError, .unsupportedVersion(99))
    }

    let fullPrivateData = try service.makeBackupData(
      from: container.mainContext,
      privacyScope: .fullPrivate
    )
    let mislabelledData = try replacingPrivacyScope(in: fullPrivateData, with: "standard")
    XCTAssertThrowsError(try service.inspect(mislabelledData)) { error in
      XCTAssertEqual(error as? PortableBackupError, .sensitiveDataRequiresFullPrivateScope)
    }
  }
}
