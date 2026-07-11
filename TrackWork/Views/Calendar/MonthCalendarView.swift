import SwiftData
import SwiftUI

struct MonthCalendarView: View {
    @Query(sort: \AttendanceDay.date) private var attendanceDays: [AttendanceDay]
    @Query(sort: \LeaveRecord.date) private var leaveRecords: [LeaveRecord]
    @Query(sort: \PublicHoliday.date) private var publicHolidays: [PublicHoliday]
    @Query(sort: \CustomExcludedDay.date) private var customExcludedDays: [CustomExcludedDay]
    @Query(sort: \ComplianceRule.createdAt) private var complianceRules: [ComplianceRule]
    @State private var displayedMonth = Date.now
    @State private var isShowingBatchLeave = false

    private let calendar = Calendar.workTrackCalendar
    private let columns = Array(repeating: GridItem(.flexible(), spacing: AppSpacing.xs), count: 7)
    private let weekdaySymbols = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    private var monthStart: Date {
        calendar.calendarViewMonthStart(for: displayedMonth)
    }

    private var monthTitle: String {
        monthStart.formatted(.dateTime.month(.wide).year())
    }

    private var calendarDays: [CalendarDay] {
        let monthDates = calendar.datesInMonth(containing: monthStart)
        let leadingBlanks = calendar.mondayBasedWeekdayIndex(for: monthStart)
        let attendanceByDay = Dictionary(grouping: attendanceDays) { attendanceDay in
            calendar.startOfDay(for: attendanceDay.date)
        }
        let leaveByDay = Dictionary(grouping: leaveRecords) { leaveRecord in
            calendar.startOfDay(for: leaveRecord.date)
        }
        let exclusionsByDay = Dictionary(grouping: customExcludedDays) { excludedDay in
            calendar.startOfDay(for: excludedDay.date)
        }
        let activeJurisdictionId = complianceRules.first?.jurisdictionId ?? "AU-VIC"
        let holidaysByDay = Dictionary(
            grouping: ActiveJurisdictionHolidayResolver.holidays(
                from: publicHolidays,
                jurisdictionId: activeJurisdictionId
            )
        ) { publicHoliday in
            calendar.startOfDay(for: publicHoliday.date)
        }

        let blankDays = (0..<leadingBlanks).map { _ in
            CalendarDay(
                date: nil,
                attendanceDay: nil,
                leaveRecord: nil,
                publicHoliday: nil,
                customExcludedDay: nil
            )
        }
        let populatedDays = monthDates.map { date in
            CalendarDay(
                date: date,
                attendanceDay: attendanceByDay[date]?.first,
                leaveRecord: leaveByDay[date]?.first,
                publicHoliday: holidaysByDay[date]?.first,
                customExcludedDay: exclusionsByDay[date]?.first
            )
        }

        return blankDays + populatedDays
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    monthHeader
                    statusLegend

                    VStack(spacing: AppSpacing.sm) {
                        weekdayHeader
                        monthGrid
                    }
                    .padding(AppSpacing.sm)
                    .glassSurface(cornerRadius: AppRadius.card, tint: Color.ds.surfaceGlass)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.vertical, AppSpacing.lg)
            }
            .appScreenBackground()
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingBatchLeave = true
                    } label: {
                        Label("Batch leave", systemImage: "calendar.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $isShowingBatchLeave) {
                BatchLeaveView(displayedMonth: monthStart)
            }
        }
    }

    private var monthHeader: some View {
        HStack(spacing: AppSpacing.sm) {
            Button {
                moveMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .glassSurface(cornerRadius: AppRadius.pill, tint: Color.ds.surfaceGlass, isInteractive: true)
            .accessibilityLabel("Previous month")

            VStack(spacing: AppSpacing.xxs) {
                Text(monthTitle)
                    .font(AppTypography.title)
                    .foregroundStyle(Color.ds.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text("Month-bound compliance period")
                    .font(AppTypography.caption)
                    .foregroundStyle(Color.ds.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)

            Button {
                moveMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .glassSurface(cornerRadius: AppRadius.pill, tint: Color.ds.surfaceGlass, isInteractive: true)
            .accessibilityLabel("Next month")
        }
        .padding(AppSpacing.sm)
        .glassSurface(cornerRadius: AppRadius.card, tint: Color.ds.surfaceGlass)
    }

    private var statusLegend: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.xs) {
                LegendPill(text: "Office", token: "O", color: Color.ds.officeDay)
                LegendPill(text: "Home", token: "H", color: Color.ds.homeDay)
                LegendPill(text: "Mixed", token: "M", color: Color.ds.info)
                LegendPill(text: "Leave", token: "AL", color: Color.ds.leaveDay)
                LegendPill(text: "Holiday", token: "PH", color: Color.ds.publicHoliday)
                LegendPill(text: "Excluded", token: "EX", color: Color.ds.textSecondary)
                LegendPill(text: "Review", token: "?", color: Color.ds.warning)
                LegendPill(text: "Upcoming", token: "—", color: Color.ds.textTertiary)
            }
            .padding(.vertical, 1)
        }
        .scrollClipDisabled()
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: AppSpacing.xs) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(AppTypography.captionStrong)
                    .foregroundStyle(Color.ds.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthGrid: some View {
        LazyVGrid(columns: columns, spacing: AppSpacing.xs) {
            ForEach(calendarDays) { day in
                if let date = day.date {
                    NavigationLink {
                        DayDetailView(
                            date: date,
                            attendanceDay: day.attendanceDay,
                            leaveRecord: day.leaveRecord,
                            publicHoliday: day.publicHoliday,
                            customExcludedDay: day.customExcludedDay
                        )
                    } label: {
                        DayCell(
                            date: date,
                            attendanceDay: day.attendanceDay,
                            leaveRecord: day.leaveRecord,
                            publicHoliday: day.publicHoliday,
                            customExcludedDay: day.customExcludedDay,
                            calendar: calendar
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear
                        .frame(height: 76)
                }
            }
        }
    }

    private func moveMonth(by offset: Int) {
        guard let nextMonth = calendar.date(byAdding: .month, value: offset, to: monthStart) else {
            return
        }

        displayedMonth = nextMonth
    }
}

#Preview {
    MonthCalendarView()
        .modelContainer(PreviewData.modelContainer())
}
