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

    @State private var displayedMonth: Date
    @State private var isShowingBatchLeave = false
    @State private var isCalendarKeyExpanded = false

    private let referenceDate: Date
    private let calendar = Calendar.workTrackCalendar
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

    private var selectedISOWeekdays: Set<Int> {
        Set(complianceRules.first?.selectedISOWeekdays ?? [1, 2, 3, 4, 5])
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
        let activeJurisdictionID = complianceRules.first?.jurisdictionId ?? "AU-VIC"
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
                customExcludedDay: exclusionsByDay[date]?.first
            )
        }
        let trailingBlanks = (0..<trailingBlankCount).map { index in
            blankDay(id: "\(monthID).trailing.\(index)")
        }

        return leadingBlanks + populatedDays + trailingBlanks
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    monthHeader

                    if dynamicTypeSize.isAccessibilitySize {
                        agenda
                    } else {
                        calendarSurface
                    }

                    calendarKey
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.vertical, AppSpacing.lg)
            }
            .appScreenBackground()
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingBatchLeave = true
                    } label: {
                        Label("Add leave for a date range", systemImage: "calendar.badge.plus")
                    }
                    .accessibilityHint("Opens batch leave entry for this month")
                }
            }
            .sheet(isPresented: $isShowingBatchLeave) {
                BatchLeaveView(displayedMonth: monthStart)
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

    private var monthHeading: some View {
        Text(monthTitle)
            .font(AppTypography.title)
            .foregroundStyle(Color.ds.textPrimary)
            .contentTransition(.numericText())
            .accessibilityAddTraits(.isHeader)
    }

    private var monthControls: some View {
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
                .buttonStyle(.bordered)
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

    private func monthButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.bordered)
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
        .background(
            Color.ds.surfacePrimary.opacity(0.72),
            in: RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .stroke(Color.ds.borderSubtle.opacity(0.72), lineWidth: 1)
        }
        .frame(maxWidth: .infinity)
        .id(monthStart)
        .transition(.opacity)
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
                            selectedISOWeekdays: selectedISOWeekdays,
                            calendar: calendar,
                            referenceDate: referenceDate
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
                            selectedISOWeekdays: selectedISOWeekdays,
                            calendar: calendar,
                            referenceDate: referenceDate
                        )
                    }
                }
            }
        }
        .padding(AppSpacing.xs)
        .background(
            Color.ds.surfacePrimary.opacity(0.72),
            in: RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .stroke(Color.ds.borderSubtle.opacity(0.72), lineWidth: 1)
        }
        .id(monthStart)
        .transition(.opacity)
    }

    private var calendarKey: some View {
        DisclosureGroup(isExpanded: $isCalendarKeyExpanded) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 132), spacing: AppSpacing.xs)],
                spacing: AppSpacing.xs
            ) {
                LegendPill(text: "Office", token: "O", color: Color.ds.officeDay)
                LegendPill(text: "Home", token: "H", color: Color.ds.homeDay)
                LegendPill(text: "Mixed", token: "M", color: Color.ds.info)
                LegendPill(text: "Annual leave", token: "AL", color: Color.ds.leaveDay)
                LegendPill(text: "Sick leave", token: "SL", color: Color.ds.leaveDay)
                LegendPill(text: "Holiday", token: "PH", color: Color.ds.publicHoliday)
                LegendPill(text: "Excluded", token: "EX", color: Color.ds.textSecondary)
                LegendPill(text: "Review", token: "!", color: Color.ds.warning)
            }
            .padding(.top, AppSpacing.sm)
        } label: {
            Label("Calendar key", systemImage: "info.circle")
                .font(AppTypography.headline)
                .foregroundStyle(Color.ds.textPrimary)
        }
        .padding(AppSpacing.md)
        .background(
            Color.ds.surfacePrimary.opacity(0.72),
            in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                .stroke(Color.ds.borderSubtle.opacity(0.64), lineWidth: 1)
        }
        .accessibilityIdentifier("calendar.key")
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
            customExcludedDay: nil
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

#Preview("Populated calendar") {
    MonthCalendarView()
        .modelContainer(PreviewData.modelContainer())
}

#Preview("Accessibility agenda") {
    MonthCalendarView()
        .modelContainer(PreviewData.modelContainer())
        .environment(\.dynamicTypeSize, .accessibility3)
}
