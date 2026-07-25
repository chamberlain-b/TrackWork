import SwiftData
import XCTest

@testable import TrackWork

struct PortableBackupReplacementFixture {
  let staleAttendanceID: UUID
  let stalePlaceID: UUID
  let bundledHolidayID: UUID
}

extension PortableBackupServiceTests {
  func makeContainer() throws -> ModelContainer {
    let schema = Schema([
      AttendanceDay.self,
      LeaveRecord.self,
      ManualAdjustment.self,
      ComplianceRule.self,
      CustomExcludedDay.self,
      PlannedOfficeDay.self,
      Place.self,
      LocationEvent.self,
      PublicHoliday.self
    ])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [configuration])
  }

  func seedCompleteStore(_ context: ModelContext) throws {
    let createdAt = date("2026-01-01")
    let updatedAt = date("2026-07-01")

    seedAttendanceData(context, createdAt: createdAt, updatedAt: updatedAt)
    seedLeaveData(context, createdAt: createdAt, updatedAt: updatedAt)
    seedComplianceRule(context, createdAt: createdAt, updatedAt: updatedAt)
    seedScheduleData(context, createdAt: createdAt, updatedAt: updatedAt)
    seedLocationData(context, createdAt: createdAt, updatedAt: updatedAt)
    seedHolidayData(context, createdAt: createdAt, updatedAt: updatedAt)
    try context.save()
  }

  func seedAttendanceData(
    _ context: ModelContext,
    createdAt: Date,
    updatedAt: Date
  ) {
    let attendanceDay = AttendanceDay(
      id: uuid(1),
      date: date("2026-07-06"),
      detectedClassification: .home,
      finalClassification: .office,
      manualClassification: .office,
      complianceTreatment: .countsAsOffice,
      officeMinutes: 240,
      homeMinutes: 180,
      note: "Private attendance note",
      createdAt: createdAt,
      updatedAt: updatedAt
    )
    context.insert(attendanceDay)
    context.insert(
      ManualAdjustment(
        id: uuid(3),
        attendanceDayId: attendanceDay.id,
        adjustedClassification: .office,
        reason: .manualCorrection,
        note: "Private adjustment note",
        createdAt: createdAt,
        updatedAt: updatedAt
      )
    )
  }

  func seedLeaveData(
    _ context: ModelContext,
    createdAt: Date,
    updatedAt: Date
  ) {
    context.insert(
      LeaveRecord(
        id: uuid(2),
        date: date("2026-07-07"),
        leaveType: .sickLeave,
        note: "Private leave note",
        createdAt: createdAt,
        updatedAt: updatedAt
      )
    )
  }

  func seedComplianceRule(
    _ context: ModelContext,
    createdAt: Date,
    updatedAt: Date
  ) {
    context.insert(
      ComplianceRule(
        id: uuid(4),
        name: "Effective rule",
        country: .newZealand,
        jurisdictionId: "NZ-AUCKLAND",
        requirementType: .percentageOfEligibleDays,
        fixedRequiredDays: nil,
        requiredPercentage: 0.4,
        minimumOfficeMinutes: 210,
        selectedISOWeekdays: [1, 2, 3, 4, 5],
        effectiveFrom: date("2026-04-01"),
        createdAt: createdAt,
        updatedAt: updatedAt
      )
    )
  }

  func seedScheduleData(
    _ context: ModelContext,
    createdAt: Date,
    updatedAt: Date
  ) {
    context.insert(
      CustomExcludedDay(
        id: uuid(5),
        date: date("2026-07-08"),
        reason: "Private exclusion",
        createdAt: createdAt,
        updatedAt: updatedAt
      )
    )
    context.insert(
      PlannedOfficeDay(
        id: uuid(6),
        date: date("2026-07-09"),
        note: "Planned with colleague",
        createdAt: createdAt,
        updatedAt: updatedAt
      )
    )
  }

  func seedLocationData(
    _ context: ModelContext,
    createdAt: Date,
    updatedAt: Date
  ) {
    let place = Place(
      id: uuid(8),
      name: "Private office",
      type: .office,
      latitude: -37.8136,
      longitude: 144.9631,
      formattedAddress: "Private office address",
      radiusMeters: 175,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
    context.insert(place)
    context.insert(
      LocationEvent(
        id: uuid(9),
        placeId: place.id,
        placeName: place.name,
        placeType: .office,
        eventKind: .entered,
        regionIdentifier: "worktrack.private.office",
        occurredAt: date("2026-07-06"),
        createdAt: createdAt
      )
    )
  }

  func seedHolidayData(
    _ context: ModelContext,
    createdAt: Date,
    updatedAt: Date
  ) {
    context.insert(
      PublicHoliday(
        id: uuid(7),
        date: date("2026-07-10"),
        name: "Private custom holiday",
        country: .newZealand,
        jurisdictionId: "NZ-AUCKLAND",
        isRegional: true,
        sourceName: "User",
        sourceURL: "https://example.invalid/private-source",
        isUserEdited: true,
        createdAt: createdAt,
        updatedAt: updatedAt
      )
    )
    context.insert(
      PublicHoliday(
        id: uuid(10),
        date: date("2026-07-11"),
        name: "Bundled holiday",
        country: .newZealand,
        jurisdictionId: "NZ-AUCKLAND",
        isRegional: false,
        sourceName: "Bundled fixture",
        createdAt: createdAt,
        updatedAt: updatedAt
      )
    )
  }

  func seedReplacementDestination(
    _ context: ModelContext
  ) throws -> PortableBackupReplacementFixture {
    let staleAttendanceID = uuid(90)
    let stalePlaceID = uuid(91)
    let bundledHolidayID = uuid(94)
    let stalePlace = Place(
      id: stalePlaceID,
      name: "Stale home",
      type: .home,
      latitude: -33.8,
      longitude: 151.2
    )

    context.insert(
      AttendanceDay(
        id: staleAttendanceID,
        date: date("2026-06-01"),
        finalClassification: .home,
        note: "Stale"
      ))
    context.insert(ComplianceRule(id: uuid(92), name: "Stale rule"))
    context.insert(stalePlace)
    context.insert(
      LocationEvent(
        id: uuid(93),
        placeId: stalePlace.id,
        placeName: stalePlace.name,
        placeType: .home,
        eventKind: .entered,
        regionIdentifier: "worktrack.stale.home"
      ))
    context.insert(
      PublicHoliday(
        id: bundledHolidayID,
        date: date("2026-08-01"),
        name: "Bundled destination holiday",
        country: .australia,
        jurisdictionId: "AU-VIC",
        isRegional: false,
        sourceName: "Bundled fixture"
      ))
    try context.save()
    return PortableBackupReplacementFixture(
      staleAttendanceID: staleAttendanceID,
      stalePlaceID: stalePlaceID,
      bundledHolidayID: bundledHolidayID
    )
  }

  func fetch<Model: PersistentModel>(
    _ modelType: Model.Type,
    from context: ModelContext
  ) throws -> [Model] {
    try context.fetch(FetchDescriptor<Model>())
  }

  func replacingManualAdjustmentReference(in data: Data, with id: UUID) throws -> Data {
    var root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    var adjustments = try XCTUnwrap(root["manualAdjustments"] as? [[String: Any]])
    adjustments[0]["attendanceDayId"] = id.uuidString
    root["manualAdjustments"] = adjustments
    return try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
  }

  func replacingPrivacyScope(in data: Data, with scope: String) throws -> Data {
    var root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    root["privacyScope"] = scope
    return try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
  }

  func uuid(_ value: Int) -> UUID {
    let suffix = String(format: "%012d", value)
    return UUID(uuidString: "00000000-0000-0000-0000-\(suffix)")!
  }

  func date(_ isoDate: String) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!

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
