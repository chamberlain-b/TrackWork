import SwiftData
import SwiftUI

struct RecordsView: View {
    @Query(sort: \AttendanceDay.date, order: .reverse) private var attendanceDays: [AttendanceDay]
    @Query(sort: \LeaveRecord.date, order: .reverse) private var leaveRecords: [LeaveRecord]
    @Query(sort: \ManualAdjustment.updatedAt, order: .reverse) private var manualAdjustments: [ManualAdjustment]
    @Query(sort: \PublicHoliday.date, order: .reverse) private var publicHolidays: [PublicHoliday]

    @State private var selectedFilter: RecordsFilter = .currentMonth

    private let calendar = Calendar.recordsCalendar

    private var filteredRecords: [RecordRow] {
        let range = selectedFilter.dateRange(calendar: calendar, now: .now)
        let attendanceByDate = Dictionary(grouping: attendanceDays) { calendar.startOfDay(for: $0.date) }
        let leaveByDate = Dictionary(grouping: leaveRecords) { calendar.startOfDay(for: $0.date) }
        let holidaysByDate = Dictionary(grouping: publicHolidays) { calendar.startOfDay(for: $0.date) }
        let adjustmentByAttendanceId = Dictionary(uniqueKeysWithValues: manualAdjustments.map { ($0.attendanceDayId, $0) })
        let allDates = Set(attendanceByDate.keys)
            .union(leaveByDate.keys)
            .union(holidaysByDate.keys)

        return allDates
            .filter { date in
                guard let range else {
                    return true
                }

                return date >= range.start && date <= range.end
            }
            .sorted(by: >)
            .map { date in
                let attendanceDay = attendanceByDate[date]?.first
                let leaveRecord = leaveByDate[date]?.first
                let publicHoliday = holidaysByDate[date]?.first
                let adjustment = attendanceDay.flatMap { adjustmentByAttendanceId[$0.id] }

                return RecordRow(
                    date: date,
                    attendanceDay: attendanceDay,
                    leaveRecord: leaveRecord,
                    publicHoliday: publicHoliday,
                    manualAdjustment: adjustment
                )
            }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Range", selection: $selectedFilter) {
                        ForEach(RecordsFilter.allCases) { filter in
                            Text(filter.displayName)
                                .tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    if filteredRecords.isEmpty {
                        DSEmptyState(
                            systemImage: "tray",
                            title: "No records",
                            message: "Attendance, leave, override, and holiday records for this range will appear here."
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

private enum RecordsFilter: String, CaseIterable, Identifiable {
    case currentMonth
    case last30Days
    case all

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .currentMonth:
            "Month"
        case .last30Days:
            "30 days"
        case .all:
            "All"
        }
    }

    func dateRange(calendar: Calendar, now: Date) -> (start: Date, end: Date)? {
        let today = calendar.startOfDay(for: now)

        switch self {
        case .currentMonth:
            return (calendar.monthStart(for: today), calendar.monthEnd(for: today))
        case .last30Days:
            let start = calendar.date(byAdding: .day, value: -29, to: today) ?? today
            return (start, today)
        case .all:
            return nil
        }
    }
}

private struct RecordRow: Identifiable {
    let id: Date
    let date: Date
    let attendanceDay: AttendanceDay?
    let leaveRecord: LeaveRecord?
    let publicHoliday: PublicHoliday?
    let manualAdjustment: ManualAdjustment?

    init(
        date: Date,
        attendanceDay: AttendanceDay?,
        leaveRecord: LeaveRecord?,
        publicHoliday: PublicHoliday?,
        manualAdjustment: ManualAdjustment?
    ) {
        self.id = date
        self.date = date
        self.attendanceDay = attendanceDay
        self.leaveRecord = leaveRecord
        self.publicHoliday = publicHoliday
        self.manualAdjustment = manualAdjustment
    }

    var primaryStatus: String {
        if let leaveType = leaveRecord?.leaveType {
            return leaveType.displayName
        }

        if publicHoliday != nil {
            return AttendanceClassification.publicHoliday.displayName
        }

        return attendanceDay?.finalClassification?.displayName ?? AttendanceClassification.unknown.displayName
    }

    var detectedStatus: String {
        attendanceDay?.detectedClassification?.displayName ?? AttendanceClassification.unknown.displayName
    }

    var note: String? {
        leaveRecord?.note ?? manualAdjustment?.note ?? attendanceDay?.note
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

    func monthStart(for date: Date) -> Date {
        dateInterval(of: .month, for: date)?.start ?? startOfDay(for: date)
    }

    func monthEnd(for date: Date) -> Date {
        guard let monthInterval = dateInterval(of: .month, for: date),
              let finalDate = self.date(byAdding: .day, value: -1, to: monthInterval.end)
        else {
            return startOfDay(for: date)
        }

        return startOfDay(for: finalDate)
    }
}

#Preview {
    RecordsView()
        .modelContainer(PreviewData.modelContainer())
}
