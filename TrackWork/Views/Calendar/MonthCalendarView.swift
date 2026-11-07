import SwiftData
import SwiftUI

// The screen keeps its grid, agenda, selection, and deterministic month data together.
// swiftlint:disable file_length
struct MonthCalendarView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Query(sort: \AttendanceDay.date) private var attendanceDays: [AttendanceDay]
    @Query(sort: \LeaveRecord.date) private var leaveRecords: [LeaveRecord]
    @Query(sort: \PublicHoliday.date) private var publicHolidays: [PublicHoliday]
    @Query(sort: \CustomExcludedDay.date) private var customExcludedDays: [CustomExcludedDay]
    @Query(sort: \ComplianceRule.createdAt) private var complianceRules: [ComplianceRule]
    @Query(sort: \PlannedOfficeDay.date) private var plannedOfficeDays: [PlannedOfficeDay]

    @State private var displayedMonth: Date
    @State private var selectedDate: Date?
    @State private var isShowingBatchLeave = false
    @State private var isShowingLegend = false
    @AppStorage("calendar.displayMode") private var displayModeRaw =
        CalendarDisplayMode.month.rawValue

    private let referenceDate: Date
    private let calendar = Calendar.workTrackCalendar
    private let ruleResolver = ComplianceRuleResolver()
    private let columns = Array(repeating: GridItem(.flexible(), spacing: AppSpacing.xxs), count: 7)

    init(referenceDate: Date = .now) {
        self.referenceDate = referenceDate
        _displayedMonth = State(initialValue: referenceDate)
        _selectedDate = State(initialValue: referenceDate)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    CalendarMonthSummary(
                        monthTitle: monthTitle,
                        isShowingCurrentMonth: isShowingCurrentMonth,
                        displayMode: displayModeSelection,
                        days: calendarDays,
                        selectedISOWeekdays: selectedISOWeekdays,
                        calendar: calendar,
                        referenceDate: referenceDate,
                        onPreviousMonth: { moveMonth(by: -1) },
                        onNextMonth: { moveMonth(by: 1) },
                        onShowCurrentMonth: showCurrentMonth
                    )

                    if let holidayCoverageWarning {
                        DSInsightCallout(
                            icon: "exclamationmark.triangle.fill",
                            message: holidayCoverageWarning,
                            highlightedText: "Holiday data unavailable"
                        )
                        .accessibilityIdentifier("calendar.holidayCoverageWarning")
                    }

                    if displayMode == .agenda {
                        selectedDayContext
                        agenda
                    } else {
                        calendarSurface
                        selectedDayContext
                    }

                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.vertical, AppSpacing.lg)
            }
            .appScreenBackground()
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        RecordsView(referenceDate: referenceDate, usesNavigationStack: false)
                    } label: {
                        Text("Records")
                    }
                    .accessibilityIdentifier("calendar.records")
                }
                CalendarPrimaryToolbar(
                    displayedMonth: monthStart,
                    referenceDate: referenceDate,
                    isShowingBatchLeave: $isShowingBatchLeave,
                    isShowingLegend: $isShowingLegend
                )
            }
            .sheet(isPresented: $isShowingBatchLeave) {
                BatchLeaveView(displayedMonth: monthStart)
            }
            .sheet(isPresented: $isShowingLegend) {
                NavigationStack {
                    ScrollView {
                        CalendarLegendGrid()
                            .padding(AppSpacing.lg)
                    }
                    .navigationTitle("Legend")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                isShowingLegend = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }
}

private extension MonthCalendarView {
    var calendarSurface: some View {
        VStack(spacing: AppSpacing.sm) {
            weekdayHeader
            monthGrid
        }
        .frame(maxWidth: 620)
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xxs)
        .summaryCardSurface()
        .id(monthStart)
        .transition(.opacity)
        .accessibilityIdentifier("calendar.monthGrid")
    }

    var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: AppSpacing.xxs) {
            ForEach(0..<7, id: \.self) { mondayBasedIndex in
                let symbolIndex = (mondayBasedIndex + 1) % 7
                Text(calendar.shortStandaloneWeekdaySymbols[symbolIndex])
                    .font(AppTypography.captionStrong)
                    .foregroundStyle(Color.ds.textSecondary)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(calendar.standaloneWeekdaySymbols[symbolIndex])
            }
        }
    }

    var monthGrid: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(calendarDays) { day in
                if let date = day.date {
                    dayButton(date: date) {
                        DayCell(
                            date: date,
                            attendanceDay: day.attendanceDay,
                            leaveRecord: day.leaveRecord,
                            publicHoliday: day.publicHoliday,
                            customExcludedDay: day.customExcludedDay,
                            plannedOfficeDay: day.plannedOfficeDay,
                            selectedISOWeekdays: selectedISOWeekdays,
                            calendar: calendar,
                            referenceDate: referenceDate,
                            isPrimaryReview: firstReviewDate.map {
                                calendar.isDate($0, inSameDayAs: date)
                            } ?? false,
                            isSelected: isSelected(date)
                        )
                    }
                } else {
                    Color.clear
                        .frame(height: 48)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    var agenda: some View {
        LazyVStack(spacing: AppSpacing.xs) {
            ForEach(calendarDays) { day in
                if let date = day.date {
                    dayButton(date: date) {
                        CalendarAgendaRow(
                            date: date,
                            attendanceDay: day.attendanceDay,
                            leaveRecord: day.leaveRecord,
                            publicHoliday: day.publicHoliday,
                            customExcludedDay: day.customExcludedDay,
                            plannedOfficeDay: day.plannedOfficeDay,
                            selectedISOWeekdays: selectedISOWeekdays,
                            calendar: calendar,
                            referenceDate: referenceDate,
                            isSelected: isSelected(date)
                        )
                    }
                }
            }
        }
        .padding(AppSpacing.xs)
        .cardSurface(includesShadow: false)
        .id(monthStart)
        .transition(.opacity)
        .accessibilityIdentifier("calendar.agenda")
    }

    var selectedDayContext: some View {
        Group {
            if let selectedCalendarDay {
                CalendarSelectedDayCard(
                    day: selectedCalendarDay,
                    selectedISOWeekdays: selectedISOWeekdays,
                    calendar: calendar,
                    referenceDate: referenceDate
                )
            }
        }
    }

    func dayButton<Label: View>(
        date: Date,
        @ViewBuilder label: () -> Label
    ) -> some View {
        Button {
            selectDate(date)
        } label: {
            label()
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected(date) ? .isSelected : [])
    }

    func blankDay(id: String) -> CalendarDay {
        CalendarDay(
            id: id,
            date: nil,
            attendanceDay: nil,
            leaveRecord: nil,
            publicHoliday: nil,
            customExcludedDay: nil,
            plannedOfficeDay: nil
        )
    }

    func presentation(
        for day: CalendarDay,
        date: Date
    ) -> CalendarDayPresentation {
        CalendarDayPresentation(
            date: date,
            attendanceDay: day.attendanceDay,
            leaveRecord: day.leaveRecord,
            publicHoliday: day.publicHoliday,
            customExcludedDay: day.customExcludedDay,
            plannedOfficeDay: day.plannedOfficeDay,
            selectedISOWeekdays: selectedISOWeekdays,
            calendar: calendar,
            referenceDate: referenceDate
        )
    }

    func moveMonth(by offset: Int) {
        guard let nextMonth = calendar.date(byAdding: .month, value: offset, to: monthStart) else {
            return
        }

        updateDisplayedMonth(nextMonth)
    }

    func showCurrentMonth() {
        updateDisplayedMonth(referenceDate)
    }

    func updateDisplayedMonth(_ date: Date) {
        if reduceMotion {
            displayedMonth = date
            selectedDate = selectionDate(for: date)
        } else {
            withAnimation(AppMotion.smooth) {
                displayedMonth = date
                selectedDate = selectionDate(for: date)
            }
        }
    }

    func selectDate(_ date: Date) {
        if reduceMotion {
            selectedDate = date
        } else {
            withAnimation(AppMotion.smooth) {
                selectedDate = date
            }
        }
    }

    func selectionDate(for month: Date) -> Date {
        if calendar.isDate(month, equalTo: referenceDate, toGranularity: .month) {
            return referenceDate
        }

        return calendar.calendarViewMonthStart(for: month)
    }

    func isSelected(_ date: Date) -> Bool {
        selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
    }
    var monthStart: Date {
        calendar.calendarViewMonthStart(for: displayedMonth)
    }

    var monthTitle: String {
        monthStart.formatted(.dateTime.month(.wide).year())
    }

    var holidayCoverageWarning: String? {
        HolidayCoverage.validation(
            from: monthStart,
            through: calendar.complianceMonthEnd(for: monthStart),
            calendar: calendar
        ).userFacingMessage
    }

    var selectedISOWeekdays: Set<Int> {
        Set(activeRule.selectedISOWeekdays)
    }

    var activeRule: ComplianceRule {
        let monthEnd = calendar.complianceMonthEnd(for: monthStart)
        return ruleResolver.rule(for: monthEnd, from: complianceRules) ?? ComplianceRule()
    }

    var isShowingCurrentMonth: Bool {
        calendar.isDate(monthStart, equalTo: referenceDate, toGranularity: .month)
    }

    var calendarDays: [CalendarDay] {
        let monthDates = calendar.datesInMonth(containing: monthStart)
        let leadingBlankCount = calendar.mondayBasedWeekdayIndex(for: monthStart)
        let populatedCount = leadingBlankCount + monthDates.count
        let trailingBlankCount = (7 - (populatedCount % 7)) % 7
        let attendanceByDay = Dictionary(grouping: attendanceDays) {
            calendar.startOfDay(for: $0.date)
        }
        let leaveByDay = Dictionary(grouping: leaveRecords) {
            calendar.startOfDay(for: $0.date)
        }
        let exclusionsByDay = Dictionary(grouping: customExcludedDays) {
            calendar.startOfDay(for: $0.date)
        }
        let plansByDay = Dictionary(grouping: plannedOfficeDays) {
            calendar.startOfDay(for: $0.date)
        }
        let activeJurisdictionID = activeRule.jurisdictionId
        let holidaysByDay = Dictionary(
            grouping: ActiveJurisdictionHolidayResolver.holidays(
                from: publicHolidays,
                jurisdictionId: activeJurisdictionID
            )
        ) {
            calendar.startOfDay(for: $0.date)
        }

        let monthID = calendar.calendarDayAccessibilityIdentifier(for: monthStart)
        let leadingBlanks = (0..<leadingBlankCount).map { index in
            blankDay(id: "\(monthID).leading.\(index)")
        }
        let populatedDays = monthDates.map { date in
            CalendarDay(
                id: calendar.calendarDayAccessibilityIdentifier(for: date),
                date: date,
                attendanceDay: attendanceByDay[date]?.first,
                leaveRecord: leaveByDay[date]?.first,
                publicHoliday: holidaysByDay[date]?.first,
                customExcludedDay: exclusionsByDay[date]?.first,
                plannedOfficeDay: plansByDay[date]?.first
            )
        }
        let trailingBlanks = (0..<trailingBlankCount).map { index in
            blankDay(id: "\(monthID).trailing.\(index)")
        }

        return leadingBlanks + populatedDays + trailingBlanks
    }

    var selectedCalendarDay: CalendarDay? {
        guard let selectedDate else {
            return nil
        }

        return calendarDays.first { day in
            guard let date = day.date else {
                return false
            }

            return calendar.isDate(date, inSameDayAs: selectedDate)
        }
    }

    var displayMode: CalendarDisplayMode {
        get {
            guard !dynamicTypeSize.isAccessibilitySize else {
                return .agenda
            }
            return CalendarDisplayMode(rawValue: displayModeRaw) ?? .month
        }
        nonmutating set {
            displayModeRaw = newValue.rawValue
        }
    }

    var displayModeSelection: Binding<CalendarDisplayMode> {
        Binding(
            get: { displayMode },
            set: { displayMode = $0 }
        )
    }

    var firstReviewDate: Date? {
        calendarDays.first { day in
            guard let date = day.date else {
                return false
            }
            return presentation(for: day, date: date).kind == .review
        }?.date
    }
}

#Preview("Populated calendar") {
    MonthCalendarView()
        .modelContainer(PreviewData.modelContainer())
}

#Preview("Accessibility agenda") {
    MonthCalendarView()
        .modelContainer(PreviewData.modelContainer())
        .environment(\.dynamicTypeSize, .accessibility3)
}
