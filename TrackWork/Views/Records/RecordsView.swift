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
    @State private var recordFilter: RecordFilter = .all
    @State private var searchText = ""

    private let onOpenCalendar: (() -> Void)?

    private let calendar = Calendar.recordsCalendar
    private let ruleResolver = ComplianceRuleResolver()

    init(onOpenCalendar: (() -> Void)? = nil) {
        self.onOpenCalendar = onOpenCalendar
    }

    private var selectedRange: ComplianceDateRange {
        selectedFilter.dateRange(
            calendar: calendar,
            now: .now,
            customStart: customRangeStart,
            customEnd: customRangeEnd
        )
    }

    private var holidayCoverageWarning: String? {
        HolidayCoverage.validation(for: selectedRange, calendar: calendar).userFacingMessage
    }

    private var periodRecords: [RecordRow] {
        let attendanceByDate = Dictionary(grouping: attendanceDays) { calendar.startOfDay(for: $0.date) }
        let leaveByDate = Dictionary(grouping: leaveRecords) { calendar.startOfDay(for: $0.date) }
        let activeJurisdictionId = ruleResolver.rule(
            for: selectedRange.end,
            from: complianceRules
        )?.jurisdictionId ?? "AU-VIC"
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
                selectedRange.contains(date, calendar: calendar)
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

    private var filteredRecords: [RecordRow] {
        periodRecords.filter { record in
            recordFilter.includes(record)
                && (searchText.isEmpty || record.matches(searchText))
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

                    Picker("Show", selection: $recordFilter) {
                        ForEach(RecordFilter.allCases) { filter in
                            Text(filter.displayName).tag(filter)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("records.statusFilter")

                    if let holidayCoverageWarning {
                        Label {
                            Text(holidayCoverageWarning)
                                .font(AppTypography.caption)
                                .foregroundStyle(Color.ds.textSecondary)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.ds.warning)
                        }
                        .accessibilityIdentifier("records.holidayCoverageWarning")
                    }
                }

                Section {
                    if filteredRecords.isEmpty {
                        VStack(spacing: AppSpacing.md) {
                            DSEmptyState(
                                systemImage: "tray",
                                title: searchText.isEmpty ? "No records" : "No matching records",
                                message: searchText.isEmpty
                                    ? "Saved attendance, leave and excluded days appear here."
                                    : "Change the search or filter."
                            )

                            if searchText.isEmpty {
                                calendarAction
                            }
                        }
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(filteredRecords) { record in
                            NavigationLink {
                                DayDetailView(
                                    date: record.date,
                                    attendanceDay: record.attendanceDay,
                                    leaveRecord: record.leaveRecord,
                                    publicHoliday: record.publicHoliday,
                                    customExcludedDay: record.customExcludedDay
                                )
                            } label: {
                                RecordRowView(record: record)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .appScreenBackground()
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Status, note, or date")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        ExportView(usesNavigationStack: false)
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("history.export")
                }
            }
        }
    }

    @ViewBuilder
    private var calendarAction: some View {
        if let onOpenCalendar {
            Button("Open Calendar", systemImage: "calendar", action: onOpenCalendar)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("records.openCalendar")
        } else {
            NavigationLink {
                MonthCalendarView()
            } label: {
                Label("Open Calendar", systemImage: "calendar")
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("records.openCalendar")
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

    func matches(_ query: String) -> Bool {
        let normalizedQuery = query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let values = [
            date.formatted(.dateTime.weekday(.wide).day().month(.wide).year()),
            primaryStatus,
            detectedStatus,
            note ?? ""
        ]
        return values.contains { value in
            value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .contains(normalizedQuery)
        }
    }
}

private enum RecordFilter: String, CaseIterable, Identifiable {
    case all
    case attendance
    case leave
    case adjusted
    case excluded

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: "All"
        case .attendance: "Attendance"
        case .leave: "Leave"
        case .adjusted: "Overrides"
        case .excluded: "Excluded"
        }
    }

    func includes(_ record: RecordRow) -> Bool {
        switch self {
        case .all:
            true
        case .attendance:
            record.attendanceDay != nil && record.leaveRecord == nil && record.customExcludedDay == nil
        case .leave:
            record.leaveRecord != nil
        case .adjusted:
            record.manualAdjustment != nil
        case .excluded:
            record.publicHoliday != nil || record.customExcludedDay != nil
        }
    }
}

private struct RecordRowView: View {
    let record: RecordRow

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                Text(record.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year()))
                    .font(AppTypography.callout.weight(.semibold))
                    .foregroundStyle(Color.ds.textPrimary)

                Spacer(minLength: AppSpacing.sm)

                DSStatusPill(
                    text: record.primaryStatus,
                    systemImage: statusImage,
                    style: statusStyle
                )
            }

            if record.manualAdjustment != nil {
                DSStatusPill(text: "Override", systemImage: "pencil", style: .warning)
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
