import SwiftData
import SwiftUI

struct MonthCalendarView: View {
    @Query(sort: \AttendanceDay.date) private var attendanceDays: [AttendanceDay]
    @State private var displayedMonth = Date.now

    private let calendar = Calendar.workTrackCalendar
    private let columns = Array(repeating: GridItem(.flexible(), spacing: AppSpacing.xs), count: 7)
    private let weekdaySymbols = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    private var monthStart: Date {
        calendar.monthStart(for: displayedMonth)
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

        let blankDays = (0..<leadingBlanks).map { _ in CalendarDay(date: nil, attendanceDay: nil) }
        let populatedDays = monthDates.map { date in
            CalendarDay(date: date, attendanceDay: attendanceByDay[date]?.first)
        }

        return blankDays + populatedDays
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    monthHeader
                    weekdayHeader
                    monthGrid
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.vertical, AppSpacing.lg)
            }
            .appScreenBackground()
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var monthHeader: some View {
        HStack(spacing: AppSpacing.sm) {
            Button {
                moveMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous month")

            Text(monthTitle)
                .font(AppTypography.title)
                .foregroundStyle(Color.ds.textPrimary)
                .frame(maxWidth: .infinity)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Button {
                moveMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next month")
        }
        .padding(AppSpacing.sm)
        .cardSurface(includesShadow: false)
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
                        DayDetailView(date: date, attendanceDay: day.attendanceDay)
                    } label: {
                        DayCell(date: date, attendanceDay: day.attendanceDay, calendar: calendar)
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

private struct CalendarDay: Identifiable {
    let id = UUID()
    let date: Date?
    let attendanceDay: AttendanceDay?
}

private struct DayCell: View {
    let date: Date
    let attendanceDay: AttendanceDay?
    let calendar: Calendar

    private var dayNumber: Int {
        calendar.component(.day, from: date)
    }

    private var status: AttendanceClassification {
        attendanceDay?.finalClassification ?? .unknown
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(dayNumber, format: .number)
                .font(AppTypography.captionStrong)
                .foregroundStyle(Color.ds.textPrimary)

            Spacer(minLength: 0)

            Text(status.calendarBadgeText)
                .font(.caption2.weight(.bold))
                .foregroundStyle(status.calendarBadgeForegroundColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 22)
                .background(status.calendarBadgeBackgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.xs, style: .continuous))
        }
        .padding(AppSpacing.xs)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)
        .background(Color.ds.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                .stroke(Color.ds.borderSubtle, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(date.formatted(.dateTime.day().month(.wide))), \(status.displayName)")
    }
}

private struct DayDetailView: View {
    let date: Date
    let attendanceDay: AttendanceDay?

    private var status: AttendanceClassification {
        attendanceDay?.finalClassification ?? .unknown
    }

    var body: some View {
        List {
            Section("Day") {
                LabeledContent("Date", value: date.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                LabeledContent("Final status", value: status.displayName)
                LabeledContent("Detected status", value: attendanceDay?.detectedClassification?.displayName ?? AttendanceClassification.unknown.displayName)
            }

            if let attendanceDay {
                Section("Attendance") {
                    LabeledContent("Office minutes", value: attendanceDay.officeMinutes.formatted())
                    LabeledContent("Home minutes", value: attendanceDay.homeMinutes.formatted())
                    LabeledContent("Compliance", value: attendanceDay.complianceTreatment?.displayName ?? ComplianceTreatment.requiresReview.displayName)
                }

                if let note = attendanceDay.note, !note.isEmpty {
                    Section("Note") {
                        Text(note)
                    }
                }
            } else {
                Section {
                    Text("No attendance record for this day yet.")
                        .foregroundStyle(Color.ds.textSecondary)
                }
            }
        }
        .navigationTitle(date.formatted(.dateTime.day().month(.wide)))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension AttendanceClassification {
    var calendarBadgeText: String {
        switch self {
        case .office:
            "O"
        case .home:
            "H"
        case .mixed:
            "M"
        case .annualLeave:
            "AL"
        case .sickLeave:
            "SL"
        case .publicHoliday:
            "PH"
        case .weekend, .nonWorkingDay, .unknown:
            "?"
        }
    }

    var calendarBadgeBackgroundColor: Color {
        switch self {
        case .office:
            Color.ds.officeDay.opacity(0.18)
        case .home:
            Color.ds.homeDay.opacity(0.18)
        case .mixed:
            Color.ds.info.opacity(0.18)
        case .annualLeave, .sickLeave:
            Color.ds.leaveDay.opacity(0.18)
        case .publicHoliday:
            Color.ds.publicHoliday.opacity(0.18)
        case .weekend, .nonWorkingDay, .unknown:
            Color.ds.surfaceSecondary
        }
    }

    var calendarBadgeForegroundColor: Color {
        switch self {
        case .office:
            Color.ds.officeDay
        case .home:
            Color.ds.homeDay
        case .mixed:
            Color.ds.info
        case .annualLeave, .sickLeave:
            Color.ds.leaveDay
        case .publicHoliday:
            Color.ds.publicHoliday
        case .weekend, .nonWorkingDay, .unknown:
            Color.ds.textTertiary
        }
    }
}

private extension Calendar {
    static var workTrackCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = .autoupdatingCurrent
        calendar.timeZone = .autoupdatingCurrent
        calendar.firstWeekday = 2
        return calendar
    }

    func monthStart(for date: Date) -> Date {
        dateInterval(of: .month, for: date)?.start ?? startOfDay(for: date)
    }

    func datesInMonth(containing date: Date) -> [Date] {
        guard let monthInterval = dateInterval(of: .month, for: date),
              let dayRange = range(of: .day, in: .month, for: monthInterval.start)
        else {
            return []
        }

        return dayRange.compactMap { day in
            self.date(byAdding: .day, value: day - 1, to: monthInterval.start)
        }
    }

    func mondayBasedWeekdayIndex(for date: Date) -> Int {
        let weekday = component(.weekday, from: date)
        return (weekday + 5) % 7
    }
}

#Preview {
    MonthCalendarView()
        .modelContainer(PreviewData.modelContainer())
}
