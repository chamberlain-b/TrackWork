import SwiftData
import SwiftUI

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
    }

    private var monthStart: Date {
        calendar.calendarViewMonthStart(for: displayedMonth)
    }

    private var monthTitle: String {
        monthStart.formatted(.dateTime.month(.wide).year())
    }

    private var holidayCoverageWarning: String? {
        HolidayCoverage.validation(
            from: monthStart,
            through: calendar.complianceMonthEnd(for: monthStart),
            calendar: calendar
        ).userFacingMessage
    }

    private var selectedISOWeekdays: Set<Int> {
        Set(activeRule.selectedISOWeekdays)
    }

    private var activeRule: ComplianceRule {
        let monthEnd = calendar.complianceMonthEnd(for: monthStart)
        return ruleResolver.rule(for: monthEnd, from: complianceRules) ?? ComplianceRule()
    }

    private var isShowingCurrentMonth: Bool {
        calendar.isDate(monthStart, equalTo: referenceDate, toGranularity: .month)
    }

    private var calendarDays: [CalendarDay] {
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

    private var displayMode: CalendarDisplayMode {
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

    private var displayModeSelection: Binding<CalendarDisplayMode> {
        Binding(
            get: { displayMode },
            set: { displayMode = $0 }
        )
    }

    private var firstReviewDate: Date? {
        calendarDays.first { day in
            guard let date = day.date else {
                return false
            }
            return presentation(for: day, date: date).kind == .review
        }?.date
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    monthHeader
                    displayModePicker

                    CalendarMonthSummary(
                        days: calendarDays,
                        selectedISOWeekdays: selectedISOWeekdays,
                        calendar: calendar,
                        referenceDate: referenceDate
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
                        agenda
                    } else {
                        calendarSurface
                    }

                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.vertical, AppSpacing.lg)
            }
            .appScreenBackground()
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
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

    private var monthHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: AppSpacing.sm) {
                monthHeading
                Spacer(minLength: AppSpacing.sm)
                monthControls
            }

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                monthHeading
                monthControls
            }
        }
    }

    private var displayModePicker: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Picker("Calendar view", selection: displayModeSelection) {
                ForEach(CalendarDisplayMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.systemImage)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .disabled(dynamicTypeSize.isAccessibilitySize)
            .accessibilityIdentifier("calendar.displayMode")

            if dynamicTypeSize.isAccessibilitySize {
                Text("Agenda view is used with larger text.")
                    .font(AppTypography.caption)
                    .foregroundStyle(Color.ds.textSecondary)
            }
        }
    }

    private var monthHeading: some View {
        Text(monthTitle)
            .font(AppTypography.title)
            .foregroundStyle(Color.ds.textPrimary)
            .contentTransition(.numericText())
            .accessibilityAddTraits(.isHeader)
    }

    private var monthControls: some View {
        GlassEffectContainer(spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.xs) {
                monthButton(
                    systemImage: "chevron.left",
                    label: "Previous month",
                    action: { moveMonth(by: -1) }
                )

                if !isShowingCurrentMonth {
                    Button("Today") {
                        showCurrentMonth()
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .accessibilityLabel("Show current month")
                    .accessibilityIdentifier("calendar.today")
                }

                monthButton(
                    systemImage: "chevron.right",
                    label: "Next month",
                    action: { moveMonth(by: 1) }
                )
            }
        }
    }

    private func monthButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.glass)
        .controlSize(.small)
        .accessibilityLabel(label)
    }

    private var calendarSurface: some View {
        VStack(spacing: AppSpacing.sm) {
            weekdayHeader
            monthGrid
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: 620)
        .cardSurface(includesShadow: false)
        .frame(maxWidth: .infinity)
        .id(monthStart)
        .transition(.opacity)
        .accessibilityIdentifier("calendar.monthGrid")
    }

    private var weekdayHeader: some View {
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

    private var monthGrid: some View {
        LazyVGrid(columns: columns, spacing: AppSpacing.xxs) {
            ForEach(calendarDays) { day in
                if let date = day.date {
                    dayLink(day: day, date: date) {
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
                            } ?? false
                        )
                    }
                } else {
                    Color.clear
                        .frame(height: 58)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    private var agenda: some View {
        LazyVStack(spacing: AppSpacing.xs) {
            ForEach(calendarDays) { day in
                if let date = day.date {
                    dayLink(day: day, date: date) {
                        CalendarAgendaRow(
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
                }
            }
        }
        .padding(AppSpacing.xs)
        .cardSurface(includesShadow: false)
        .id(monthStart)
        .transition(.opacity)
        .accessibilityIdentifier("calendar.agenda")
    }

    private func dayLink<Label: View>(
        day: CalendarDay,
        date: Date,
        @ViewBuilder label: () -> Label
    ) -> some View {
        NavigationLink {
            DayDetailView(
                date: date,
                attendanceDay: day.attendanceDay,
                leaveRecord: day.leaveRecord,
                publicHoliday: day.publicHoliday,
                customExcludedDay: day.customExcludedDay
            )
        } label: {
            label()
        }
        .buttonStyle(.plain)
    }

    private func blankDay(id: String) -> CalendarDay {
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

    private func presentation(
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

    private func moveMonth(by offset: Int) {
        guard let nextMonth = calendar.date(byAdding: .month, value: offset, to: monthStart) else {
            return
        }

        updateDisplayedMonth(nextMonth)
    }

    private func showCurrentMonth() {
        updateDisplayedMonth(referenceDate)
    }

    private func updateDisplayedMonth(_ date: Date) {
        if reduceMotion {
            displayedMonth = date
        } else {
            withAnimation(AppMotion.smooth) {
                displayedMonth = date
            }
        }
    }
}

private enum CalendarDisplayMode: String, CaseIterable, Identifiable {
    case month
    case agenda

    var id: Self { self }

    var title: String {
        switch self {
        case .month:
            "Month"
        case .agenda:
            "Agenda"
        }
    }

    var systemImage: String {
        switch self {
        case .month:
            "calendar"
        case .agenda:
            "list.bullet"
        }
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
