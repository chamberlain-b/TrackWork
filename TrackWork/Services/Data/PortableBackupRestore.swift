import Foundation
import SwiftData

struct PortableBackupReconciliationMapping<Record, Model: PersistentModel> {
  let recordID: KeyPath<Record, UUID>
  let modelID: KeyPath<Model, UUID>
  let update: (Model, Record) -> Void
  let make: (Record) throws -> Model
}

extension PortableBackupService {
  func apply(
    _ archive: PortableBackupArchive,
    policy: PortableBackupRestorePolicy,
    to modelContext: ModelContext
  ) throws {
    let replacing = policy == .replace

    try applyAttendanceDomains(archive, replacing: replacing, to: modelContext)
    try applyComplianceDomains(archive, replacing: replacing, to: modelContext)
    try applyEditedHolidays(archive, replacing: replacing, to: modelContext)

    guard archive.privacyScope == .fullPrivate else {
      return
    }
    try applyLocationDomains(archive, replacing: replacing, to: modelContext)
  }

  func applyAttendanceDomains(
    _ archive: PortableBackupArchive,
    replacing: Bool,
    to modelContext: ModelContext
  ) throws {
    try reconcile(
      archive.attendanceDays,
      with: try fetch(AttendanceDay.self, from: modelContext),
      replacing: replacing,
      in: modelContext,
      mapping: PortableBackupReconciliationMapping(
        recordID: \.id,
        modelID: \.id,
        update: update,
        make: makeAttendanceDay
      )
    )
    try reconcile(
      archive.leaveRecords,
      with: try fetch(LeaveRecord.self, from: modelContext),
      replacing: replacing,
      in: modelContext,
      mapping: PortableBackupReconciliationMapping(
        recordID: \.id,
        modelID: \.id,
        update: update,
        make: makeLeaveRecord
      )
    )
    try reconcile(
      archive.manualAdjustments,
      with: try fetch(ManualAdjustment.self, from: modelContext),
      replacing: replacing,
      in: modelContext,
      mapping: PortableBackupReconciliationMapping(
        recordID: \.id,
        modelID: \.id,
        update: update,
        make: makeManualAdjustment
      )
    )
  }

  func applyComplianceDomains(
    _ archive: PortableBackupArchive,
    replacing: Bool,
    to modelContext: ModelContext
  ) throws {
    try reconcile(
      archive.complianceRules,
      with: try fetch(ComplianceRule.self, from: modelContext),
      replacing: replacing,
      in: modelContext,
      mapping: PortableBackupReconciliationMapping(
        recordID: \.id,
        modelID: \.id,
        update: update,
        make: makeComplianceRule
      )
    )
    try reconcile(
      archive.customExcludedDays,
      with: try fetch(CustomExcludedDay.self, from: modelContext),
      replacing: replacing,
      in: modelContext,
      mapping: PortableBackupReconciliationMapping(
        recordID: \.id,
        modelID: \.id,
        update: update,
        make: makeCustomExcludedDay
      )
    )
    try reconcile(
      archive.plannedOfficeDays,
      with: try fetch(PlannedOfficeDay.self, from: modelContext),
      replacing: replacing,
      in: modelContext,
      mapping: PortableBackupReconciliationMapping(
        recordID: \.id,
        modelID: \.id,
        update: update,
        make: makePlannedOfficeDay
      )
    )
  }

  func applyEditedHolidays(
    _ archive: PortableBackupArchive,
    replacing: Bool,
    to modelContext: ModelContext
  ) throws {
    let userEditedHolidays = try fetch(PublicHoliday.self, from: modelContext)
      .filter(\.isUserEdited)
    try reconcile(
      archive.userEditedHolidays,
      with: userEditedHolidays,
      replacing: replacing,
      in: modelContext,
      mapping: PortableBackupReconciliationMapping(
        recordID: \.id,
        modelID: \.id,
        update: update,
        make: makePublicHoliday
      )
    )
  }

  func applyLocationDomains(
    _ archive: PortableBackupArchive,
    replacing: Bool,
    to modelContext: ModelContext
  ) throws {
    try reconcile(
      archive.places,
      with: try fetch(Place.self, from: modelContext),
      replacing: replacing,
      in: modelContext,
      mapping: PortableBackupReconciliationMapping(
        recordID: \.id,
        modelID: \.id,
        update: update,
        make: makePlace
      )
    )
    try reconcile(
      archive.locationEvents,
      with: try fetch(LocationEvent.self, from: modelContext),
      replacing: replacing,
      in: modelContext,
      mapping: PortableBackupReconciliationMapping(
        recordID: \.id,
        modelID: \.id,
        update: update,
        make: makeLocationEvent
      )
    )
  }

  func reconcile<Record, Model: PersistentModel>(
    _ records: [Record],
    with existingModels: [Model],
    replacing: Bool,
    in modelContext: ModelContext,
    mapping: PortableBackupReconciliationMapping<Record, Model>
  ) throws {
    var existingByID: [UUID: Model] = [:]
    for model in existingModels {
      let id = model[keyPath: mapping.modelID]
      guard existingByID[id] == nil else {
        throw PortableBackupError.invalidPayload(
          "The current store contains duplicate identifiers.")
      }
      existingByID[id] = model
    }

    if replacing {
      let incomingIDs = Set(records.map { $0[keyPath: mapping.recordID] })
      for model in existingModels where !incomingIDs.contains(model[keyPath: mapping.modelID]) {
        modelContext.delete(model)
      }
    }

    for record in records {
      let id = record[keyPath: mapping.recordID]
      if let existing = existingByID[id] {
        mapping.update(existing, record)
      } else {
        modelContext.insert(try mapping.make(record))
      }
    }
  }
}
