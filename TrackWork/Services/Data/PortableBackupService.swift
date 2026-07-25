import Foundation
import SwiftData

/// Creates and restores local, versioned JSON backups of Work Track's SwiftData source of truth.
/// UserDefaults-owned preferences, including reminder and privacy-lock preferences, are intentionally
/// outside this contract. Standard backups also omit all saved-place and raw location-event data.
@MainActor
struct PortableBackupService {
  static let maximumPayloadSize = 100 * 1_024 * 1_024

  func makeBackupData(
    from modelContext: ModelContext,
    privacyScope: PortableBackupPrivacyScope = .standard
  ) throws -> Data {
    let archive = try makeArchive(from: modelContext, privacyScope: privacyScope)
    try validate(archive)
    try validateReferences(in: archive, policy: .replace, modelContext: modelContext)

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .millisecondsSince1970
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(archive)
  }

  func inspect(_ data: Data) throws -> PortableBackupInspection {
    let archive = try decodeAndValidate(data)
    return PortableBackupInspection(
      formatVersion: archive.formatVersion,
      privacyScope: archive.privacyScope,
      recordCounts: archive.recordCounts
    )
  }

  func restore(
    _ data: Data,
    policy: PortableBackupRestorePolicy,
    into modelContext: ModelContext
  ) throws -> PortableBackupRestoreResult {
    let archive = try decodeAndValidate(data)
    guard !modelContext.hasChanges else {
      throw PortableBackupError.unsavedChanges
    }

    try validateReferences(in: archive, policy: policy, modelContext: modelContext)

    do {
      try apply(archive, policy: policy, to: modelContext)
      try modelContext.save()
    } catch {
      modelContext.rollback()
      throw error
    }

    return PortableBackupRestoreResult(
      policy: policy,
      privacyScope: archive.privacyScope,
      recordCounts: archive.recordCounts
    )
  }
}

extension PortableBackupService {
  struct ArchiveHeader: Decodable {
    let formatIdentifier: String
    let formatVersion: Int
  }

  func makeArchive(
    from modelContext: ModelContext,
    privacyScope: PortableBackupPrivacyScope
  ) throws -> PortableBackupArchive {
    let attendanceDays = sortedByID(try fetch(AttendanceDay.self, from: modelContext))
      .map(PortableBackupArchive.AttendanceDayRecord.init)
    let leaveRecords = sortedByID(try fetch(LeaveRecord.self, from: modelContext))
      .map(PortableBackupArchive.LeaveRecordRecord.init)
    let manualAdjustments = sortedByID(try fetch(ManualAdjustment.self, from: modelContext))
      .map(PortableBackupArchive.ManualAdjustmentRecord.init)
    let complianceRules = sortedByID(try fetch(ComplianceRule.self, from: modelContext))
      .map(PortableBackupArchive.ComplianceRuleRecord.init)
    let customExcludedDays = sortedByID(try fetch(CustomExcludedDay.self, from: modelContext))
      .map(PortableBackupArchive.CustomExcludedDayRecord.init)
    let plannedOfficeDays = sortedByID(try fetch(PlannedOfficeDay.self, from: modelContext))
      .map(PortableBackupArchive.PlannedOfficeDayRecord.init)
    let userEditedHolidays = sortedByID(
      try fetch(PublicHoliday.self, from: modelContext).filter(\.isUserEdited)
    ).map(PortableBackupArchive.PublicHolidayRecord.init)

    let places: [PortableBackupArchive.PlaceRecord]
    let locationEvents: [PortableBackupArchive.LocationEventRecord]
    switch privacyScope {
    case .standard:
      places = []
      locationEvents = []
    case .fullPrivate:
      places = sortedByID(try fetch(Place.self, from: modelContext))
        .map(PortableBackupArchive.PlaceRecord.init)
      locationEvents = sortedByID(try fetch(LocationEvent.self, from: modelContext))
        .map(PortableBackupArchive.LocationEventRecord.init)
    }

    return PortableBackupArchive(
      privacyScope: privacyScope,
      attendanceDays: attendanceDays,
      leaveRecords: leaveRecords,
      manualAdjustments: manualAdjustments,
      complianceRules: complianceRules,
      customExcludedDays: customExcludedDays,
      plannedOfficeDays: plannedOfficeDays,
      userEditedHolidays: userEditedHolidays,
      places: places,
      locationEvents: locationEvents
    )
  }

  func decodeAndValidate(_ data: Data) throws -> PortableBackupArchive {
    guard data.count <= Self.maximumPayloadSize else {
      throw PortableBackupError.payloadTooLarge
    }

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .millisecondsSince1970

    let header: ArchiveHeader
    do {
      header = try decoder.decode(ArchiveHeader.self, from: data)
    } catch {
      throw PortableBackupError.corruptPayload
    }

    guard header.formatIdentifier == PortableBackupArchive.formatIdentifier else {
      throw PortableBackupError.unsupportedFormat
    }
    guard header.formatVersion == PortableBackupArchive.currentFormatVersion else {
      throw PortableBackupError.unsupportedVersion(header.formatVersion)
    }

    let archive: PortableBackupArchive
    do {
      archive = try decoder.decode(PortableBackupArchive.self, from: data)
    } catch {
      throw PortableBackupError.corruptPayload
    }

    try validate(archive)
    return archive
  }

  func fetch<Model: PersistentModel>(
    _ modelType: Model.Type,
    from modelContext: ModelContext
  ) throws -> [Model] {
    try modelContext.fetch(FetchDescriptor<Model>())
  }

  func sortedByID<Model>(_ values: [Model]) -> [Model] where Model: PersistentModel {
    values.sorted { lhs, rhs in
      persistentID(for: lhs).uuidString < persistentID(for: rhs).uuidString
    }
  }

  func persistentID<Model: PersistentModel>(for model: Model) -> UUID {
    switch model {
    case let model as AttendanceDay:
      model.id
    case let model as LeaveRecord:
      model.id
    case let model as ManualAdjustment:
      model.id
    case let model as ComplianceRule:
      model.id
    case let model as CustomExcludedDay:
      model.id
    case let model as PlannedOfficeDay:
      model.id
    case let model as PublicHoliday:
      model.id
    case let model as Place:
      model.id
    case let model as LocationEvent:
      model.id
    default:
      preconditionFailure("Portable backup received an unsupported persistent model")
    }
  }
}
