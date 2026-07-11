import Foundation

struct ReportSnapshot: Equatable {
    let id: UUID
    let summary: Summary
    let dailyRecords: [DailyRecordRow]
    let leaveRows: [LeaveRow]
    let customExclusionRows: [CustomExclusionRow]
    let manualAdjustmentRows: [ManualAdjustmentRow]
    let noteRows: [NoteRow]
    let publicHolidayRows: [PublicHolidayRow]
    let ruleSummary: RuleSummary
    let options: Options

    init(
        id: UUID = UUID(),
        summary: Summary,
        dailyRecords: [DailyRecordRow],
        leaveRows: [LeaveRow],
        customExclusionRows: [CustomExclusionRow],
        manualAdjustmentRows: [ManualAdjustmentRow],
        noteRows: [NoteRow],
        publicHolidayRows: [PublicHolidayRow],
        ruleSummary: RuleSummary,
        options: Options
    ) {
        self.id = id
        self.summary = summary
        self.dailyRecords = dailyRecords
        self.leaveRows = leaveRows
        self.customExclusionRows = customExclusionRows
        self.manualAdjustmentRows = manualAdjustmentRows
        self.noteRows = noteRows
        self.publicHolidayRows = publicHolidayRows
        self.ruleSummary = ruleSummary
        self.options = options
    }
}

extension ReportSnapshot {
    struct Options: Equatable {
        let includeNotes: Bool

        init(includeNotes: Bool = true) {
            self.includeNotes = includeNotes
        }
    }

    struct Summary: Equatable {
        let periodStart: Date
        let periodEnd: Date
        let generatedAt: Date
        let baseEligibleDays: Int
        let adjustedEligibleDays: Int
        let adjustedRequiredOfficeDays: Int
        let completedOfficeDays: Int
        let reviewRequiredDays: Int
        let customExcludedDays: Int
        let leaveSummary: LeaveSummary
    }

    struct LeaveSummary: Equatable {
        let annualLeaveDays: Int
        let sickLeaveDays: Int
        let totalLeaveDays: Int
    }

    struct DailyRecordRow: Equatable, Identifiable {
        let id: UUID
        let date: Date
        let isoDate: String
        let detectedStatus: AttendanceClassification
        let finalStatus: AttendanceClassification
        let complianceTreatment: ComplianceTreatment
        let officeMinutes: Int
        let homeMinutes: Int
        let isSelectedWorkday: Bool
        let isPublicHoliday: Bool
        let hasLeave: Bool
        let isCustomExcluded: Bool
        let note: String?

        init(
            id: UUID = UUID(),
            date: Date,
            isoDate: String,
            detectedStatus: AttendanceClassification,
            finalStatus: AttendanceClassification,
            complianceTreatment: ComplianceTreatment,
            officeMinutes: Int,
            homeMinutes: Int,
            isSelectedWorkday: Bool,
            isPublicHoliday: Bool,
            hasLeave: Bool,
            isCustomExcluded: Bool,
            note: String?
        ) {
            self.id = id
            self.date = date
            self.isoDate = isoDate
            self.detectedStatus = detectedStatus
            self.finalStatus = finalStatus
            self.complianceTreatment = complianceTreatment
            self.officeMinutes = officeMinutes
            self.homeMinutes = homeMinutes
            self.isSelectedWorkday = isSelectedWorkday
            self.isPublicHoliday = isPublicHoliday
            self.hasLeave = hasLeave
            self.isCustomExcluded = isCustomExcluded
            self.note = note
        }
    }

    struct LeaveRow: Equatable, Identifiable {
        let id: UUID
        let date: Date
        let isoDate: String
        let type: LeaveType
        let duration: LeaveDuration
        let countsAgainstEligibleDay: Bool
        let note: String?
    }

    struct CustomExclusionRow: Equatable, Identifiable {
        let id: UUID
        let date: Date
        let isoDate: String
        let reducesEligibleDays: Bool
        let reason: String?
    }

    struct ManualAdjustmentRow: Equatable, Identifiable {
        let id: UUID
        let date: Date
        let isoDate: String
        let adjustedClassification: AttendanceClassification
        let reason: OverrideReason
        let note: String?
    }

    struct NoteRow: Equatable, Identifiable {
        enum Source: String, Equatable {
            case attendanceDay
            case leave
            case manualAdjustment
        }

        let id: UUID
        let date: Date
        let isoDate: String
        let source: Source
        let text: String
    }

    struct PublicHolidayRow: Equatable, Identifiable {
        let id: UUID
        let date: Date
        let isoDate: String
        let name: String
        let countryCode: String
        let jurisdictionId: String
        let isRegional: Bool
        let sourceName: String
        let sourceURL: String?
    }

    struct RuleSummary: Equatable {
        let ruleName: String
        let countryCode: String
        let jurisdictionId: String
        let requirementType: RequirementType
        let fixedRequiredDays: Int?
        let requiredPercentage: Double?
        let prorateFixedTargetForLeave: Bool
        let minimumOfficeMinutes: Int
        let selectedISOWeekdays: [Int]
    }
}
