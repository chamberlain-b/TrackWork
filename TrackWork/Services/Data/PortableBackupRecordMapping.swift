import Foundation

extension PortableBackupArchive.AttendanceDayRecord {
  init(_ model: AttendanceDay) {
    self.init(
      id: model.id,
      date: model.date,
      detectedClassificationRaw: model.detectedClassificationRaw,
      finalClassificationRaw: model.finalClassificationRaw,
      manualClassificationRaw: model.manualClassificationRaw,
      complianceTreatmentRaw: model.complianceTreatmentRaw,
      officeMinutes: model.officeMinutes,
      homeMinutes: model.homeMinutes,
      note: model.note,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt
    )
  }
}

extension PortableBackupArchive.LeaveRecordRecord {
  init(_ model: LeaveRecord) {
    self.init(
      id: model.id,
      date: model.date,
      leaveTypeRaw: model.leaveTypeRaw,
      durationRaw: model.durationRaw,
      note: model.note,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt
    )
  }
}

extension PortableBackupArchive.ManualAdjustmentRecord {
  init(_ model: ManualAdjustment) {
    self.init(
      id: model.id,
      attendanceDayId: model.attendanceDayId,
      adjustedClassificationRaw: model.adjustedClassificationRaw,
      reasonRaw: model.reasonRaw,
      note: model.note,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt
    )
  }
}

extension PortableBackupArchive.ComplianceRuleRecord {
  init(_ model: ComplianceRule) {
    self.init(
      id: model.id,
      name: model.name,
      countryCode: model.countryCode,
      jurisdictionId: model.jurisdictionId,
      requirementTypeRaw: model.requirementTypeRaw,
      fixedRequiredDays: model.fixedRequiredDays,
      requiredPercentage: model.requiredPercentage,
      prorateFixedTargetForLeave: model.prorateFixedTargetForLeave,
      minimumOfficeMinutes: model.minimumOfficeMinutes,
      selectedISOWeekdays: model.selectedISOWeekdays,
      effectiveFrom: model.effectiveFrom,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt
    )
  }
}

extension PortableBackupArchive.CustomExcludedDayRecord {
  init(_ model: CustomExcludedDay) {
    self.init(
      id: model.id,
      date: model.date,
      reason: model.reason,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt
    )
  }
}

extension PortableBackupArchive.PlannedOfficeDayRecord {
  init(_ model: PlannedOfficeDay) {
    self.init(
      id: model.id,
      date: model.date,
      note: model.note,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt
    )
  }
}

extension PortableBackupArchive.PublicHolidayRecord {
  init(_ model: PublicHoliday) {
    self.init(
      id: model.id,
      date: model.date,
      name: model.name,
      countryCode: model.countryCode,
      jurisdictionId: model.jurisdictionId,
      isRegional: model.isRegional,
      sourceName: model.sourceName,
      sourceURL: model.sourceURL,
      isUserEdited: model.isUserEdited,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt
    )
  }
}

extension PortableBackupArchive.PlaceRecord {
  init(_ model: Place) {
    self.init(
      id: model.id,
      name: model.name,
      typeRaw: model.typeRaw,
      latitude: model.latitude,
      longitude: model.longitude,
      formattedAddress: model.formattedAddress,
      radiusMeters: model.radiusMeters,
      isActive: model.isActive,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt
    )
  }
}

extension PortableBackupArchive.LocationEventRecord {
  init(_ model: LocationEvent) {
    self.init(
      id: model.id,
      placeId: model.placeId,
      placeName: model.placeName,
      placeTypeRaw: model.placeTypeRaw,
      eventKindRaw: model.eventKindRaw,
      regionIdentifier: model.regionIdentifier,
      occurredAt: model.occurredAt,
      createdAt: model.createdAt
    )
  }
}
