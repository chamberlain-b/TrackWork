import Foundation

extension PortableBackupService {
  func update(_ model: AttendanceDay, from record: PortableBackupArchive.AttendanceDayRecord) {
    model.date = record.date
    model.detectedClassificationRaw = record.detectedClassificationRaw
    model.finalClassificationRaw = record.finalClassificationRaw
    model.manualClassificationRaw = record.manualClassificationRaw
    model.complianceTreatmentRaw = record.complianceTreatmentRaw
    model.officeMinutes = record.officeMinutes
    model.homeMinutes = record.homeMinutes
    model.note = record.note
    model.createdAt = record.createdAt
    model.updatedAt = record.updatedAt
  }

  func makeAttendanceDay(
    from record: PortableBackupArchive.AttendanceDayRecord
  ) throws -> AttendanceDay {
    guard
      let detectedClassification = AttendanceClassification(
        rawValue: record.detectedClassificationRaw
      ),
      let finalClassification = AttendanceClassification(rawValue: record.finalClassificationRaw),
      let complianceTreatment = ComplianceTreatment(rawValue: record.complianceTreatmentRaw)
    else {
      throw PortableBackupError.invalidPayload(
        "An attendance day contains an unknown classification.")
    }
    let manualClassification: AttendanceClassification?
    if let rawValue = record.manualClassificationRaw {
      guard let classification = AttendanceClassification(rawValue: rawValue) else {
        throw PortableBackupError.invalidPayload(
          "An attendance day contains an unknown classification.")
      }
      manualClassification = classification
    } else {
      manualClassification = nil
    }

    return AttendanceDay(
      id: record.id,
      date: record.date,
      detectedClassification: detectedClassification,
      finalClassification: finalClassification,
      manualClassification: manualClassification,
      complianceTreatment: complianceTreatment,
      officeMinutes: record.officeMinutes,
      homeMinutes: record.homeMinutes,
      note: record.note,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt
    )
  }

  func update(_ model: LeaveRecord, from record: PortableBackupArchive.LeaveRecordRecord) {
    model.date = record.date
    model.leaveTypeRaw = record.leaveTypeRaw
    model.durationRaw = record.durationRaw
    model.note = record.note
    model.createdAt = record.createdAt
    model.updatedAt = record.updatedAt
  }

  func makeLeaveRecord(
    from record: PortableBackupArchive.LeaveRecordRecord
  ) throws -> LeaveRecord {
    guard let leaveType = LeaveType(rawValue: record.leaveTypeRaw),
      let duration = LeaveDuration(rawValue: record.durationRaw)
    else {
      throw PortableBackupError.invalidPayload("A leave record contains an unknown value.")
    }
    return LeaveRecord(
      id: record.id,
      date: record.date,
      leaveType: leaveType,
      duration: duration,
      note: record.note,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt
    )
  }

  func update(
    _ model: ManualAdjustment,
    from record: PortableBackupArchive.ManualAdjustmentRecord
  ) {
    model.attendanceDayId = record.attendanceDayId
    model.adjustedClassificationRaw = record.adjustedClassificationRaw
    model.reasonRaw = record.reasonRaw
    model.note = record.note
    model.createdAt = record.createdAt
    model.updatedAt = record.updatedAt
  }

  func makeManualAdjustment(
    from record: PortableBackupArchive.ManualAdjustmentRecord
  ) throws -> ManualAdjustment {
    guard
      let adjustedClassification = AttendanceClassification(
        rawValue: record.adjustedClassificationRaw
      ), let reason = OverrideReason(rawValue: record.reasonRaw)
    else {
      throw PortableBackupError.invalidPayload("A manual adjustment contains an unknown value.")
    }
    return ManualAdjustment(
      id: record.id,
      attendanceDayId: record.attendanceDayId,
      adjustedClassification: adjustedClassification,
      reason: reason,
      note: record.note,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt
    )
  }

  func update(_ model: ComplianceRule, from record: PortableBackupArchive.ComplianceRuleRecord) {
    model.name = record.name
    model.countryCode = record.countryCode
    model.jurisdictionId = record.jurisdictionId
    model.requirementTypeRaw = record.requirementTypeRaw
    model.fixedRequiredDays = record.fixedRequiredDays
    model.requiredPercentage = record.requiredPercentage
    model.prorateFixedTargetForLeave = record.prorateFixedTargetForLeave
    model.minimumOfficeMinutes = record.minimumOfficeMinutes
    model.selectedISOWeekdays = record.selectedISOWeekdays
    model.effectiveFrom = record.effectiveFrom
    model.createdAt = record.createdAt
    model.updatedAt = record.updatedAt
  }

  func makeComplianceRule(
    from record: PortableBackupArchive.ComplianceRuleRecord
  ) throws -> ComplianceRule {
    guard let country = Country(rawValue: record.countryCode),
      let requirementType = RequirementType(rawValue: record.requirementTypeRaw)
    else {
      throw PortableBackupError.invalidPayload(
        "A compliance rule contains unknown identity values.")
    }
    return ComplianceRule(
      id: record.id,
      name: record.name,
      country: country,
      jurisdictionId: record.jurisdictionId,
      requirementType: requirementType,
      fixedRequiredDays: record.fixedRequiredDays,
      requiredPercentage: record.requiredPercentage,
      prorateFixedTargetForLeave: record.prorateFixedTargetForLeave,
      minimumOfficeMinutes: record.minimumOfficeMinutes,
      selectedISOWeekdays: record.selectedISOWeekdays,
      effectiveFrom: record.effectiveFrom,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt
    )
  }

  func update(
    _ model: CustomExcludedDay,
    from record: PortableBackupArchive.CustomExcludedDayRecord
  ) {
    model.date = record.date
    model.reason = record.reason
    model.createdAt = record.createdAt
    model.updatedAt = record.updatedAt
  }

  func makeCustomExcludedDay(
    from record: PortableBackupArchive.CustomExcludedDayRecord
  ) throws -> CustomExcludedDay {
    CustomExcludedDay(
      id: record.id,
      date: record.date,
      reason: record.reason,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt
    )
  }

  func update(
    _ model: PlannedOfficeDay,
    from record: PortableBackupArchive.PlannedOfficeDayRecord
  ) {
    model.date = record.date
    model.note = record.note
    model.createdAt = record.createdAt
    model.updatedAt = record.updatedAt
  }

  func makePlannedOfficeDay(
    from record: PortableBackupArchive.PlannedOfficeDayRecord
  ) throws -> PlannedOfficeDay {
    PlannedOfficeDay(
      id: record.id,
      date: record.date,
      note: record.note,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt
    )
  }

  func update(_ model: PublicHoliday, from record: PortableBackupArchive.PublicHolidayRecord) {
    model.date = record.date
    model.name = record.name
    model.countryCode = record.countryCode
    model.jurisdictionId = record.jurisdictionId
    model.isRegional = record.isRegional
    model.sourceName = record.sourceName
    model.sourceURL = record.sourceURL
    model.isUserEdited = record.isUserEdited
    model.createdAt = record.createdAt
    model.updatedAt = record.updatedAt
  }

  func makePublicHoliday(
    from record: PortableBackupArchive.PublicHolidayRecord
  ) throws -> PublicHoliday {
    guard let country = Country(rawValue: record.countryCode) else {
      throw PortableBackupError.invalidPayload("An edited holiday contains an unknown country.")
    }
    return PublicHoliday(
      id: record.id,
      date: record.date,
      name: record.name,
      country: country,
      jurisdictionId: record.jurisdictionId,
      isRegional: record.isRegional,
      sourceName: record.sourceName,
      sourceURL: record.sourceURL,
      isUserEdited: record.isUserEdited,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt
    )
  }

  func update(_ model: Place, from record: PortableBackupArchive.PlaceRecord) {
    model.name = record.name
    model.typeRaw = record.typeRaw
    model.latitude = record.latitude
    model.longitude = record.longitude
    model.formattedAddress = record.formattedAddress
    model.radiusMeters = record.radiusMeters
    model.isActive = record.isActive
    model.createdAt = record.createdAt
    model.updatedAt = record.updatedAt
  }

  func makePlace(from record: PortableBackupArchive.PlaceRecord) throws -> Place {
    guard let type = PlaceType(rawValue: record.typeRaw) else {
      throw PortableBackupError.invalidPayload("A saved place contains an unknown type.")
    }
    return Place(
      id: record.id,
      name: record.name,
      type: type,
      latitude: record.latitude,
      longitude: record.longitude,
      formattedAddress: record.formattedAddress,
      radiusMeters: record.radiusMeters,
      isActive: record.isActive,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt
    )
  }

  func update(_ model: LocationEvent, from record: PortableBackupArchive.LocationEventRecord) {
    model.placeId = record.placeId
    model.placeName = record.placeName
    model.placeTypeRaw = record.placeTypeRaw
    model.eventKindRaw = record.eventKindRaw
    model.regionIdentifier = record.regionIdentifier
    model.occurredAt = record.occurredAt
    model.createdAt = record.createdAt
  }

  func makeLocationEvent(
    from record: PortableBackupArchive.LocationEventRecord
  ) throws -> LocationEvent {
    guard let placeType = PlaceType(rawValue: record.placeTypeRaw),
      let eventKind = LocationEventKind(rawValue: record.eventKindRaw)
    else {
      throw PortableBackupError.invalidPayload("A location event contains an unknown value.")
    }
    return LocationEvent(
      id: record.id,
      placeId: record.placeId,
      placeName: record.placeName,
      placeType: placeType,
      eventKind: eventKind,
      regionIdentifier: record.regionIdentifier,
      occurredAt: record.occurredAt,
      createdAt: record.createdAt
    )
  }
}
