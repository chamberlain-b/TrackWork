import Foundation
import SwiftData

extension PortableBackupService {
  func validate(_ archive: PortableBackupArchive) throws {
    guard archive.formatIdentifier == PortableBackupArchive.formatIdentifier else {
      throw PortableBackupError.unsupportedFormat
    }
    guard archive.formatVersion == PortableBackupArchive.currentFormatVersion else {
      throw PortableBackupError.unsupportedVersion(archive.formatVersion)
    }
    if archive.privacyScope == .standard && (
      !archive.places.isEmpty || !archive.locationEvents.isEmpty
    ) {
      throw PortableBackupError.sensitiveDataRequiresFullPrivateScope
    }

    try validateCollectionIDs(in: archive)
    try validateAttendanceData(in: archive)
    try validateComplianceData(in: archive)
    try validateHolidayData(in: archive)
    try validateLocationData(in: archive)
  }

  func validateCollectionIDs(in archive: PortableBackupArchive) throws {
    try validateUniqueIDs(archive.attendanceDays.map(\.id), domain: "attendance days")
    try validateUniqueIDs(archive.leaveRecords.map(\.id), domain: "leave records")
    try validateUniqueIDs(archive.manualAdjustments.map(\.id), domain: "manual adjustments")
    try validateUniqueIDs(archive.complianceRules.map(\.id), domain: "compliance rules")
    try validateUniqueIDs(archive.customExcludedDays.map(\.id), domain: "excluded days")
    try validateUniqueIDs(archive.plannedOfficeDays.map(\.id), domain: "planned office days")
    try validateUniqueIDs(archive.userEditedHolidays.map(\.id), domain: "edited holidays")
    try validateUniqueIDs(archive.places.map(\.id), domain: "places")
    try validateUniqueIDs(archive.locationEvents.map(\.id), domain: "location events")
  }

  func validateAttendanceData(in archive: PortableBackupArchive) throws {
    let adjustedAttendanceDayIDs = archive.manualAdjustments.map(\.attendanceDayId)
    guard Set(adjustedAttendanceDayIDs).count == adjustedAttendanceDayIDs.count else {
      throw PortableBackupError.invalidPayload(
        "Multiple manual adjustments reference the same attendance day.")
    }

    for record in archive.attendanceDays {
      try validateDates(record.date, record.createdAt, record.updatedAt)
      guard AttendanceClassification(rawValue: record.detectedClassificationRaw) != nil,
        AttendanceClassification(rawValue: record.finalClassificationRaw) != nil,
        record.manualClassificationRaw.map({ AttendanceClassification(rawValue: $0) != nil })
          ?? true,
        ComplianceTreatment(rawValue: record.complianceTreatmentRaw) != nil
      else {
        throw PortableBackupError.invalidPayload(
          "An attendance day contains an unknown classification.")
      }
      guard record.officeMinutes >= 0, record.homeMinutes >= 0 else {
        throw PortableBackupError.invalidPayload("Attendance minutes cannot be negative.")
      }
    }

    for record in archive.leaveRecords {
      try validateDates(record.date, record.createdAt, record.updatedAt)
      guard LeaveType(rawValue: record.leaveTypeRaw) != nil,
        LeaveDuration(rawValue: record.durationRaw) != nil
      else {
        throw PortableBackupError.invalidPayload("A leave record contains an unknown value.")
      }
    }

    for record in archive.manualAdjustments {
      try validateDates(record.createdAt, record.updatedAt)
      guard AttendanceClassification(rawValue: record.adjustedClassificationRaw) != nil,
        OverrideReason(rawValue: record.reasonRaw) != nil
      else {
        throw PortableBackupError.invalidPayload("A manual adjustment contains an unknown value.")
      }
    }
  }

  func validateComplianceData(in archive: PortableBackupArchive) throws {
    for record in archive.complianceRules {
      try validateDates(record.createdAt, record.updatedAt)
      if let effectiveFrom = record.effectiveFrom {
        try validateDates(effectiveFrom)
      }
      guard !record.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        !record.jurisdictionId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        Country(rawValue: record.countryCode) != nil,
        let requirementType = RequirementType(rawValue: record.requirementTypeRaw)
      else {
        throw PortableBackupError.invalidPayload(
          "A compliance rule contains unknown identity values.")
      }
      let weekdays = Set(record.selectedISOWeekdays)
      let preferredWeekdays = Set(record.preferredOfficeISOWeekdays ?? [])
      guard !weekdays.isEmpty,
        weekdays.count == record.selectedISOWeekdays.count,
        weekdays.allSatisfy({ (1...7).contains($0) }),
        preferredWeekdays.count == (record.preferredOfficeISOWeekdays ?? []).count,
        preferredWeekdays.allSatisfy({ (1...7).contains($0) }),
        preferredWeekdays.isSubset(of: weekdays),
        record.minimumOfficeMinutes >= 0,
        record.fixedRequiredDays.map({ $0 >= 0 }) ?? true,
        record.requiredPercentage.map({ $0.isFinite && (0...1).contains($0) }) ?? true
      else {
        throw PortableBackupError.invalidPayload(
          "A compliance rule has invalid requirement values.")
      }
      switch requirementType {
      case .fixedMonthlyDays:
        guard record.fixedRequiredDays != nil else {
          throw PortableBackupError.invalidPayload("A fixed compliance rule has no day target.")
        }
      case .percentageOfEligibleDays:
        guard record.requiredPercentage != nil else {
          throw PortableBackupError.invalidPayload(
            "A percentage compliance rule has no percentage target.")
        }
      }
    }

    for record in archive.customExcludedDays {
      try validateDates(record.date, record.createdAt, record.updatedAt)
    }
    for record in archive.plannedOfficeDays {
      try validateDates(record.date, record.createdAt, record.updatedAt)
    }
  }

  func validateHolidayData(in archive: PortableBackupArchive) throws {
    for record in archive.userEditedHolidays {
      try validateDates(record.date, record.createdAt, record.updatedAt)
      guard record.isUserEdited,
        Country(rawValue: record.countryCode) != nil,
        !record.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        !record.jurisdictionId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        !record.sourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else {
        throw PortableBackupError.invalidPayload("An edited holiday contains invalid values.")
      }
    }
  }

  func validateLocationData(in archive: PortableBackupArchive) throws {
    for record in archive.places {
      try validateDates(record.createdAt, record.updatedAt)
      guard PlaceType(rawValue: record.typeRaw) != nil,
        !record.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        record.latitude.isFinite,
        (-90...90).contains(record.latitude),
        record.longitude.isFinite,
        (-180...180).contains(record.longitude),
        record.radiusMeters.isFinite,
        record.radiusMeters > 0
      else {
        throw PortableBackupError.invalidPayload("A saved place contains invalid values.")
      }
    }

    for record in archive.locationEvents {
      try validateDates(record.occurredAt, record.createdAt)
      guard PlaceType(rawValue: record.placeTypeRaw) != nil,
        LocationEventKind(rawValue: record.eventKindRaw) != nil,
        !record.placeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        !record.regionIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else {
        throw PortableBackupError.invalidPayload("A location event contains invalid values.")
      }
    }
  }

  func validateUniqueIDs(_ ids: [UUID], domain: String) throws {
    guard Set(ids).count == ids.count else {
      throw PortableBackupError.invalidPayload(
        "The \(domain) collection contains duplicate identifiers.")
    }
  }

  func validateDates(_ dates: Date...) throws {
    guard dates.allSatisfy({ $0.timeIntervalSinceReferenceDate.isFinite }) else {
      throw PortableBackupError.invalidPayload("The backup contains an invalid date.")
    }
  }

  func validateReferences(
    in archive: PortableBackupArchive,
    policy: PortableBackupRestorePolicy,
    modelContext: ModelContext
  ) throws {
    let incomingAttendanceIDs = Set(archive.attendanceDays.map(\.id))
    let validAttendanceIDs: Set<UUID>
    switch policy {
    case .replace:
      validAttendanceIDs = incomingAttendanceIDs
    case .mergePreferBackup:
      let localIDs = try fetch(AttendanceDay.self, from: modelContext).map(\.id)
      validAttendanceIDs = incomingAttendanceIDs.union(localIDs)
    }
    guard archive.manualAdjustments.allSatisfy({ validAttendanceIDs.contains($0.attendanceDayId) })
    else {
      throw PortableBackupError.invalidPayload(
        "A manual adjustment references a missing attendance day.")
    }

    let incomingPlaceIDs = Set(archive.places.map(\.id))
    let validPlaceIDs: Set<UUID>
    switch policy {
    case .replace:
      validPlaceIDs = incomingPlaceIDs
    case .mergePreferBackup:
      let localIDs = try fetch(Place.self, from: modelContext).map(\.id)
      validPlaceIDs = incomingPlaceIDs.union(localIDs)
    }
    guard
      archive.locationEvents.allSatisfy({ record in
        record.placeId.map(validPlaceIDs.contains) ?? true
      })
    else {
      throw PortableBackupError.invalidPayload("A location event references a missing saved place.")
    }

    let incomingHolidayIDs = Set(archive.userEditedHolidays.map(\.id))
    let bundledHolidayIDs = Set(
      try fetch(PublicHoliday.self, from: modelContext)
        .filter { !$0.isUserEdited }
        .map(\.id)
    )
    guard incomingHolidayIDs.isDisjoint(with: bundledHolidayIDs) else {
      throw PortableBackupError.invalidPayload(
        "An edited holiday conflicts with bundled holiday data.")
    }
  }
}
