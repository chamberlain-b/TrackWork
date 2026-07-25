import Foundation

enum PortableBackupPrivacyScope: String, Codable, Sendable {
  /// Excludes saved places, their precise coordinates and addresses, and raw location events.
  case standard

  /// Includes all user-owned SwiftData records, including sensitive location data.
  case fullPrivate
}

enum PortableBackupRestorePolicy: Equatable, Sendable {
  /// Makes each represented domain match the backup. Standard backups preserve location domains.
  case replace

  /// Upserts by stable identifier. Backup values win and local-only records are preserved.
  case mergePreferBackup
}

struct PortableBackupRecordCounts: Equatable, Sendable {
  let attendanceDays: Int
  let leaveRecords: Int
  let manualAdjustments: Int
  let complianceRules: Int
  let customExcludedDays: Int
  let plannedOfficeDays: Int
  let userEditedHolidays: Int
  let places: Int
  let locationEvents: Int

  var total: Int {
    attendanceDays
      + leaveRecords
      + manualAdjustments
      + complianceRules
      + customExcludedDays
      + plannedOfficeDays
      + userEditedHolidays
      + places
      + locationEvents
  }
}

struct PortableBackupInspection: Equatable, Sendable {
  let formatVersion: Int
  let privacyScope: PortableBackupPrivacyScope
  let recordCounts: PortableBackupRecordCounts
}

struct PortableBackupRestoreResult: Equatable, Sendable {
  let policy: PortableBackupRestorePolicy
  let privacyScope: PortableBackupPrivacyScope
  let recordCounts: PortableBackupRecordCounts
}

enum PortableBackupError: Error, Equatable {
  case corruptPayload
  case payloadTooLarge
  case unsupportedFormat
  case unsupportedVersion(Int)
  case invalidPayload(String)
  case sensitiveDataRequiresFullPrivateScope
  case unsavedChanges
}

extension PortableBackupError: LocalizedError {
  var errorDescription: String? {
    switch self {
    case .corruptPayload:
      "The selected file is not a valid Work Track backup."
    case .payloadTooLarge:
      "The selected backup is too large to import safely."
    case .unsupportedFormat:
      "The selected file is not a Work Track portable backup."
    case .unsupportedVersion(let version):
      "This backup uses unsupported format version \(version)."
    case .invalidPayload(let reason):
      "The backup could not be validated: \(reason)"
    case .sensitiveDataRequiresFullPrivateScope:
      "Location records are only allowed in a full private backup."
    case .unsavedChanges:
      "Save pending changes before restoring a backup."
    }
  }
}

struct PortableBackupArchive: Codable, Equatable {
  static let formatIdentifier = "com.benchamberlain.worktrack.portable-backup"
  static let currentFormatVersion = 1

  let formatIdentifier: String
  let formatVersion: Int
  let privacyScope: PortableBackupPrivacyScope
  let attendanceDays: [AttendanceDayRecord]
  let leaveRecords: [LeaveRecordRecord]
  let manualAdjustments: [ManualAdjustmentRecord]
  let complianceRules: [ComplianceRuleRecord]
  let customExcludedDays: [CustomExcludedDayRecord]
  let plannedOfficeDays: [PlannedOfficeDayRecord]
  let userEditedHolidays: [PublicHolidayRecord]
  let places: [PlaceRecord]
  let locationEvents: [LocationEventRecord]

  init(
    privacyScope: PortableBackupPrivacyScope,
    attendanceDays: [AttendanceDayRecord],
    leaveRecords: [LeaveRecordRecord],
    manualAdjustments: [ManualAdjustmentRecord],
    complianceRules: [ComplianceRuleRecord],
    customExcludedDays: [CustomExcludedDayRecord],
    plannedOfficeDays: [PlannedOfficeDayRecord],
    userEditedHolidays: [PublicHolidayRecord],
    places: [PlaceRecord],
    locationEvents: [LocationEventRecord]
  ) {
    self.formatIdentifier = Self.formatIdentifier
    self.formatVersion = Self.currentFormatVersion
    self.privacyScope = privacyScope
    self.attendanceDays = attendanceDays
    self.leaveRecords = leaveRecords
    self.manualAdjustments = manualAdjustments
    self.complianceRules = complianceRules
    self.customExcludedDays = customExcludedDays
    self.plannedOfficeDays = plannedOfficeDays
    self.userEditedHolidays = userEditedHolidays
    self.places = places
    self.locationEvents = locationEvents
  }

  var recordCounts: PortableBackupRecordCounts {
    PortableBackupRecordCounts(
      attendanceDays: attendanceDays.count,
      leaveRecords: leaveRecords.count,
      manualAdjustments: manualAdjustments.count,
      complianceRules: complianceRules.count,
      customExcludedDays: customExcludedDays.count,
      plannedOfficeDays: plannedOfficeDays.count,
      userEditedHolidays: userEditedHolidays.count,
      places: places.count,
      locationEvents: locationEvents.count
    )
  }
}

extension PortableBackupArchive {
  struct AttendanceDayRecord: Codable, Equatable {
    let id: UUID
    let date: Date
    let detectedClassificationRaw: String
    let finalClassificationRaw: String
    let manualClassificationRaw: String?
    let complianceTreatmentRaw: String
    let officeMinutes: Int
    let homeMinutes: Int
    let note: String?
    let createdAt: Date
    let updatedAt: Date
  }

  struct LeaveRecordRecord: Codable, Equatable {
    let id: UUID
    let date: Date
    let leaveTypeRaw: String
    let durationRaw: String
    let note: String?
    let createdAt: Date
    let updatedAt: Date
  }

  struct ManualAdjustmentRecord: Codable, Equatable {
    let id: UUID
    let attendanceDayId: UUID
    let adjustedClassificationRaw: String
    let reasonRaw: String
    let note: String?
    let createdAt: Date
    let updatedAt: Date
  }

  struct ComplianceRuleRecord: Codable, Equatable {
    let id: UUID
    let name: String
    let countryCode: String
    let jurisdictionId: String
    let requirementTypeRaw: String
    let fixedRequiredDays: Int?
    let requiredPercentage: Double?
    let prorateFixedTargetForLeave: Bool
    let minimumOfficeMinutes: Int
    let selectedISOWeekdays: [Int]
    let effectiveFrom: Date?
    let createdAt: Date
    let updatedAt: Date
  }

  struct CustomExcludedDayRecord: Codable, Equatable {
    let id: UUID
    let date: Date
    let reason: String?
    let createdAt: Date
    let updatedAt: Date
  }

  struct PlannedOfficeDayRecord: Codable, Equatable {
    let id: UUID
    let date: Date
    let note: String?
    let createdAt: Date
    let updatedAt: Date
  }

  struct PublicHolidayRecord: Codable, Equatable {
    let id: UUID
    let date: Date
    let name: String
    let countryCode: String
    let jurisdictionId: String
    let isRegional: Bool
    let sourceName: String
    let sourceURL: String?
    let isUserEdited: Bool
    let createdAt: Date
    let updatedAt: Date
  }

  struct PlaceRecord: Codable, Equatable {
    let id: UUID
    let name: String
    let typeRaw: String
    let latitude: Double
    let longitude: Double
    let formattedAddress: String?
    let radiusMeters: Double
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date
  }

  struct LocationEventRecord: Codable, Equatable {
    let id: UUID
    let placeId: UUID?
    let placeName: String
    let placeTypeRaw: String
    let eventKindRaw: String
    let regionIdentifier: String
    let occurredAt: Date
    let createdAt: Date
  }
}
