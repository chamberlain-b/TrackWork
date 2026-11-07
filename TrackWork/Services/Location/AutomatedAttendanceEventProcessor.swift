import Foundation
import SwiftData

@MainActor
struct AutomatedAttendanceEventProcessor {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func recalculateAttendance(
        affectedBy event: LocationEvent,
        in modelContext: ModelContext
    ) throws {
        var data = try AutomatedAttendanceData(modelContext: modelContext)
        let affectedDates = LocationEventDateResolver(calendar: calendar)
            .affectedDates(for: event, among: data.locationEvents)

        for affectedDate in affectedDates.sorted() {
            if event.eventKind == .confirmedOutside || event.eventKind == .monitoringStopped,
               !data.attendanceDays.contains(where: { calendar.startOfDay(for: $0.date) == affectedDate }) {
                // Keep closing evidence for late event delivery, but it cannot
                // create an attendance day or establish any duration.
                continue
            }
            recalculate(affectedDate, data: &data, modelContext: modelContext)
        }
    }

    private func recalculate(
        _ affectedDate: Date,
        data: inout AutomatedAttendanceData,
        modelContext: ModelContext
    ) {
        let attendanceDay = data.attendanceDay(
            for: affectedDate,
            calendar: calendar,
            modelContext: modelContext
        )
        let rule = ComplianceRuleResolver().rule(for: affectedDate, from: data.rules)
        let applicablePublicHolidays = ActiveJurisdictionHolidayResolver.holidays(
            from: data.publicHolidays,
            jurisdictionId: rule?.jurisdictionId ?? "AU-VIC"
        )
        let minimumOfficeMinutes = rule?.minimumOfficeMinutes ?? 180
        let inferenceService = AttendanceInferenceService(
            calendar: calendar,
            minimumOfficeMinutes: minimumOfficeMinutes
        )

        inferenceService.recalculateAttendanceDays(
            data.attendanceDays,
            affectedDates: [affectedDate],
            events: data.locationEvents,
            leaveRecords: data.leaveRecords,
            publicHolidays: applicablePublicHolidays,
            customExcludedDays: data.customExcludedDays,
            selectedISOWeekdays: Set(rule?.selectedISOWeekdays ?? [1, 2, 3, 4, 5])
        )

        guard completedOfficeVisit(attendanceDay, minimumOfficeMinutes: minimumOfficeMinutes) else {
            return
        }

        data.plannedOfficeDays
            .filter { calendar.startOfDay(for: $0.date) == affectedDate }
            .forEach(modelContext.delete)
    }

    private func completedOfficeVisit(
        _ attendanceDay: AttendanceDay,
        minimumOfficeMinutes: Int
    ) -> Bool {
        switch attendanceDay.finalClassification {
        case .office:
            true
        case .mixed:
            attendanceDay.officeMinutes >= minimumOfficeMinutes
        default:
            false
        }
    }
}

@MainActor
private struct AutomatedAttendanceData {
    var attendanceDays: [AttendanceDay]
    let locationEvents: [LocationEvent]
    let leaveRecords: [LeaveRecord]
    let publicHolidays: [PublicHoliday]
    let customExcludedDays: [CustomExcludedDay]
    let rules: [ComplianceRule]
    let plannedOfficeDays: [PlannedOfficeDay]

    init(modelContext: ModelContext) throws {
        attendanceDays = try modelContext.fetch(FetchDescriptor<AttendanceDay>())
        locationEvents = try modelContext.fetch(FetchDescriptor<LocationEvent>())
        leaveRecords = try modelContext.fetch(FetchDescriptor<LeaveRecord>())
        publicHolidays = try modelContext.fetch(FetchDescriptor<PublicHoliday>())
        customExcludedDays = try modelContext.fetch(FetchDescriptor<CustomExcludedDay>())
        rules = try modelContext.fetch(FetchDescriptor<ComplianceRule>())
        plannedOfficeDays = try modelContext.fetch(FetchDescriptor<PlannedOfficeDay>())
    }

    mutating func attendanceDay(
        for date: Date,
        calendar: Calendar,
        modelContext: ModelContext
    ) -> AttendanceDay {
        if let existingDay = attendanceDays.first(where: { calendar.startOfDay(for: $0.date) == date }) {
            return existingDay
        }

        let attendanceDay = AttendanceDay(date: date)
        modelContext.insert(attendanceDay)
        attendanceDays.append(attendanceDay)
        return attendanceDay
    }
}
