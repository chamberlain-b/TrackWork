import Foundation

enum RecordFilter: String, CaseIterable, Identifiable {
    case all
    case attendance
    case leave
    case adjusted
    case excluded

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all:
            "All"
        case .attendance:
            "Attendance"
        case .leave:
            "Leave"
        case .adjusted:
            "Overrides"
        case .excluded:
            "Excluded"
        }
    }

    func includes(_ record: RecordRow) -> Bool {
        switch self {
        case .all:
            true
        case .attendance:
            record.attendanceDay != nil
                && record.leaveRecord == nil
                && record.customExcludedDay == nil
        case .leave:
            record.leaveRecord != nil
        case .adjusted:
            record.manualAdjustment != nil
        case .excluded:
            record.publicHoliday != nil || record.customExcludedDay != nil
        }
    }
}

struct RecordRow: Identifiable {
    let id: Date
    let date: Date
    let attendanceDay: AttendanceDay?
    let leaveRecord: LeaveRecord?
    let publicHoliday: PublicHoliday?
    let customExcludedDay: CustomExcludedDay?
    let manualAdjustment: ManualAdjustment?

    init(
        date: Date,
        attendanceDay: AttendanceDay?,
        leaveRecord: LeaveRecord?,
        publicHoliday: PublicHoliday?,
        customExcludedDay: CustomExcludedDay?,
        manualAdjustment: ManualAdjustment?
    ) {
        self.id = date
        self.date = date
        self.attendanceDay = attendanceDay
        self.leaveRecord = leaveRecord
        self.publicHoliday = publicHoliday
        self.customExcludedDay = customExcludedDay
        self.manualAdjustment = manualAdjustment
    }

    var primaryStatus: String {
        if let leaveType = leaveRecord?.leaveType {
            return leaveType.displayName
        }

        if publicHoliday != nil {
            return AttendanceClassification.publicHoliday.displayName
        }

        if customExcludedDay != nil {
            return "Excluded"
        }

        return attendanceDay?.finalClassification?.displayName
            ?? AttendanceClassification.unknown.displayName
    }

    var detectedStatus: String {
        attendanceDay?.detectedClassification?.displayName
            ?? AttendanceClassification.unknown.displayName
    }

    var adjustedStatus: String {
        manualAdjustment?.adjustedClassification?.displayName
            ?? attendanceDay?.finalClassification?.displayName
            ?? primaryStatus
    }

    var note: String? {
        leaveRecord?.note ?? customExcludedDay?.reason ?? manualAdjustment?.note ?? attendanceDay?.note
    }

    var accessibilityIdentifier: String {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "history.record.%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    func matches(_ query: String) -> Bool {
        let normalizedQuery = query.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )
        let values = [
            date.formatted(.dateTime.weekday(.wide).day().month(.wide).year()),
            primaryStatus,
            detectedStatus,
            adjustedStatus,
            manualAdjustment?.reason?.displayName ?? "",
            note ?? ""
        ]
        return values.contains { value in
            value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .contains(normalizedQuery)
        }
    }
}
