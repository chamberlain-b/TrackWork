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
    @State private var customRangeStart: Date
    @State private var customRangeEnd: Date
    @State private var recordFilter: RecordFilter = .all
    @State private var searchText = ""

    private let onOpenCalendar: (() -> Void)?
    private let referenceDate: Date
    private let usesNavigationStack: Bool
    @Environment(\.dismiss) private var dismiss

    private let calendar = Calendar.recordsCalendar
    private let ruleResolver = ComplianceRuleResolver()

    init(
        onOpenCalendar: (() -> Void)? = nil,
        referenceDate: Date = .now,
        usesNavigationStack: Bool = true
    ) {
        self.onOpenCalendar = onOpenCalendar
        self.referenceDate = referenceDate
        self.usesNavigationStack = usesNavigationStack
        _customRangeStart = State(initialValue: referenceDate)
        _customRangeEnd = State(initialValue: referenceDate)
    }

    private var selectedRange: ComplianceDateRange {
        selectedFilter.dateRange(
            calendar: calendar,
            now: referenceDate,
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

    private var recordGroups: [HistoryRecordGroup] {
        Dictionary(grouping: filteredRecords) { record in
            calendar.dateInterval(of: .month, for: record.date)?.start
                ?? calendar.startOfDay(for: record.date)
        }
        .map { monthStart, records in
            HistoryRecordGroup(monthStart: monthStart, records: records.sorted { $0.date > $1.date })
        }
        .sorted { $0.monthStart > $1.monthStart }
    }

    private var adjustedRecordCount: Int {
        periodRecords.filter { $0.manualAdjustment != nil }.count
    }

    private var periodDateRangeTitle: String {
        let start = selectedRange.start.formatted(.dateTime.day().month(.abbreviated).year())
        let end = selectedRange.end.formatted(.dateTime.day().month(.abbreviated).year())
        return start == end ? start : "\(start) – \(end)"
    }

    private var isFilteringRecords: Bool {
        recordFilter != .all || !searchText.isEmpty
    }

    var body: some View {
        Group {
            if usesNavigationStack { NavigationStack { screenContent } }
            else { screenContent }
        }
    }

    private var screenContent: some View {
        Group {
            List {
                Section {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        HistoryFilterCard(
                            selectedPreset: $selectedFilter,
                            customStart: $customRangeStart,
                            customEnd: $customRangeEnd,
                            recordFilter: $recordFilter
                        )

                        HistoryOverviewCard(
                            dateRangeTitle: periodDateRangeTitle,
                            recordCount: periodRecords.count,
                            adjustedRecordCount: adjustedRecordCount
                        )
                    }
                }
                .historyCardListRow()

                if let holidayCoverageWarning {
                    Section {
                        DSInsightCallout(
                            icon: "exclamationmark.triangle.fill",
                            message: holidayCoverageWarning,
                            highlightedText: "Holiday data unavailable"
                        )
                        .accessibilityIdentifier("records.holidayCoverageWarning")
                    }
                    .historyCardListRow()
                }

                if filteredRecords.isEmpty {
                    Section {
                        VStack(spacing: AppSpacing.md) {
                            DSEmptyState(
                                systemImage: emptyStateImage,
                                title: emptyStateTitle,
                                message: emptyStateMessage
                            )

                            if periodRecords.isEmpty && !isFilteringRecords {
                                calendarAction
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .historyCardListRow()
                } else {
                    ForEach(recordGroups) { group in
                        Section {
                            ForEach(group.records) { record in
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
                                .listRowInsets(
                                    EdgeInsets(
                                        top: AppSpacing.xs,
                                        leading: AppSpacing.screenHorizontal,
                                        bottom: AppSpacing.xs,
                                        trailing: AppSpacing.screenHorizontal
                                    )
                                )
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.visible)
                            }
                        } header: {
                            HistoryMonthHeader(
                                title: group.title,
                                recordCount: group.records.count
                            )
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .appScreenBackground()
            .navigationTitle("Records")
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

    private var emptyStateImage: String {
        periodRecords.isEmpty ? "tray" : "line.3.horizontal.decrease.circle"
    }

    private var emptyStateTitle: String {
        if periodRecords.isEmpty {
            return "No records in this period"
        }

        return "No matching records"
    }

    private var emptyStateMessage: String {
        if periodRecords.isEmpty {
            return "Attendance, leave, holidays and excluded days will appear here."
        }

        return "Change the search or filter to see more records."
    }

    @ViewBuilder
    private var calendarAction: some View {
        if let onOpenCalendar {
            Button("Open Calendar", systemImage: "calendar", action: onOpenCalendar)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("records.openCalendar")
        } else {
            NavigationLink {
                MonthCalendarView(referenceDate: referenceDate)
            } label: {
                Label("Open Calendar", systemImage: "calendar")
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("records.openCalendar")
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
    RecordsView(referenceDate: PreviewData.planConfidenceReferenceDate)
        .modelContainer(PreviewData.modelContainer())
}
