import SwiftData
import SwiftUI

struct RecordsView: View {
    @Query(sort: \AttendanceDay.date, order: .reverse) private var attendanceDays: [AttendanceDay]
    @Query(sort: \LeaveRecord.date, order: .reverse) private var leaveRecords: [LeaveRecord]
    @Query(sort: \ManualAdjustment.updatedAt, order: .reverse) private var manualAdjustments: [ManualAdjustment]
    @Query(sort: \PublicHoliday.date, order: .reverse) private var publicHolidays: [PublicHoliday]
    @Query(sort: \CustomExcludedDay.date, order: .reverse) private var customExcludedDays: [CustomExcludedDay]
    @Query(sort: \ComplianceRule.createdAt) private var complianceRules: [ComplianceRule]

    @State private var selectedFilter: CompliancePeriodPreset = .currentMonth
    @State private var customRangeStart: Date = .now
    @State private var customRangeEnd: Date = .now

    private let calendar = Calendar.recordsCalendar

    private var filteredRecords: [RecordRow] {
        let range = selectedFilter.dateRange(
            calendar: calendar,
            now: .now,
            customStart: customRangeStart,
            customEnd: customRangeEnd
        )
        let attendanceByDate = Dictionary(grouping: attendanceDays) { calendar.startOfDay(for: $0.date) }
        let leaveByDate = Dictionary(grouping: leaveRecords) { calendar.startOfDay(for: $0.date) }
        let activeJurisdictionId = complianceRules.first?.jurisdictionId ?? "AU-VIC"
        let applicableHolidays = publicHolidays.filter { holiday in
            holiday.jurisdictionId == activeJurisdictionId
        }
        let holidaysByDate = Dictionary(grouping: applicableHolidays) { calendar.startOfDay(for: $0.date) }
        let exclusionsByDate = Dictionary(grouping: customExcludedDays) { calendar.startOfDay(for: $0.date) }
        let adjustmentByAttendanceId = Dictionary(
            uniqueKeysWithValues: manualAdjustments.map { ($0.attendanceDayId, $0) }
        )
        let allDates = Set(attendanceByDate.keys)
            .union(leaveByDate.keys)
            .union(holidaysByDate.keys)
            .union(exclusionsByDate.keys)

        return allDates
            .filter { date in
                range.contains(date, calendar: calendar)
            }
            .sorted(by: >)
            .map { date in
                let attendanceDay = attendanceByDate[date]?.first
                let leaveRecord = leaveByDate[date]?.first
                let publicHoliday = holidaysByDate[date]?.first
                let customExcludedDay = exclusionsByDate[date]?.first
                let adjustment = attendanceDay.flatMap { adjustmentByAttendanceId[$0.id] }

                return RecordRow(
                    date: date,
                    attendanceDay: attendanceDay,
                    leaveRecord: leaveRecord,
                    publicHoliday: publicHoliday,
                    customExcludedDay: customExcludedDay,
                    manualAdjustment: adjustment
                )
            }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    CompliancePeriodControls(
                        selectedPreset: $selectedFilter,
                        customStart: $customRangeStart,
                        customEnd: $customRangeEnd,
                        accessibilityPrefix: "records"
                    )
                }

                Section {
                    if filteredRecords.isEmpty {
                        DSEmptyState(
                            systemImage: "tray",
                            title: "No records",
                            message: "Attendance, leave, overrides, holidays, and custom exclusions for this range will appear here."
                        )
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(filteredRecords) { record in
                            RecordRowView(record: record)
                        }
                    }
                } header: {
                    Text("Records")
                }
            }
            .scrollContentBackground(.hidden)
            .appScreenBackground()
            .navigationTitle("Records")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct RecordRow: Identifiable {
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

        return attendanceDay?.finalClassification?.displayName ?? AttendanceClassification.unknown.displayName
    }

    var detectedStatus: String {
        attendanceDay?.detectedClassification?.displayName ?? AttendanceClassification.unknown.displayName
    }

    var note: String? {
        leaveRecord?.note ?? customExcludedDay?.reason ?? manualAdjustment?.note ?? attendanceDay?.note
    }
}

private struct RecordRowView: View {
    let record: RecordRow

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(record.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year()))
                        .font(AppTypography.callout.weight(.semibold))
                        .foregroundStyle(Color.ds.textPrimary)

                    Text("Detected: \(record.detectedStatus)")
                        .font(AppTypography.caption)
                        .foregroundStyle(Color.ds.textSecondary)
                }

                Spacer(minLength: AppSpacing.sm)

                DSStatusPill(
                    text: record.primaryStatus,
                    systemImage: statusImage,
                    style: statusStyle
                )
            }

            HStack(spacing: AppSpacing.xs) {
                if record.manualAdjustment != nil {
                    DSStatusPill(text: "Override", systemImage: "pencil", style: .warning)
                }

                if record.leaveRecord != nil {
                    DSStatusPill(text: "Leave", systemImage: "sun.max", style: .info)
                }

                if record.publicHoliday != nil {
                    DSStatusPill(text: "Public holiday", systemImage: "sparkles", style: .neutral)
                }

                if record.customExcludedDay != nil {
                    DSStatusPill(text: "Custom exclusion", systemImage: "calendar.badge.minus", style: .neutral)
                }
            }

            if let note = record.note, !note.isEmpty {
                Text(note)
                    .font(AppTypography.caption)
                    .foregroundStyle(Color.ds.textSecondary)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, AppSpacing.xs)
        .accessibilityElement(children: .combine)
    }

    private var statusImage: String {
        if record.leaveRecord != nil {
            return "sun.max"
        }

        if record.publicHoliday != nil {
            return "sparkles"
        }

        if record.customExcludedDay != nil {
            return "calendar.badge.minus"
        }

        switch record.attendanceDay?.finalClassification ?? .unknown {
        case .office:
            return "building.2"
        case .home:
            return "house"
        case .mixed:
            return "arrow.triangle.2.circlepath"
        case .annualLeave, .sickLeave:
            return "sun.max"
        case .publicHoliday:
            return "sparkles"
        case .weekend, .nonWorkingDay:
            return "calendar"
        case .unknown:
            return "questionmark.circle"
        }
    }

    private var statusStyle: DSStatusPillStyle {
        if record.leaveRecord != nil {
            return .info
        }

        if record.publicHoliday != nil {
            return .neutral
        }

        if record.customExcludedDay != nil {
            return .neutral
        }

        switch record.attendanceDay?.finalClassification ?? .unknown {
        case .office:
            return .success
        case .home, .mixed:
            return .neutral
        case .annualLeave, .sickLeave:
            return .info
        case .publicHoliday, .weekend, .nonWorkingDay:
            return .neutral
        case .unknown:
            return .warning
        }
    }
}

private extension Calendar {
    static var recordsCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = .autoupdatingCurrent
        calendar.timeZone = .autoupdatingCurrent
        calendar.firstWeekday = 2
        return calendar
    }
}

#Preview {
    RecordsView()
        .modelContainer(PreviewData.modelContainer())
}
