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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ManualAdjustment.updatedAt, order: .reverse) private var manualAdjustments: [ManualAdjustment]
    @Query(sort: \LeaveRecord.date) private var leaveRecords: [LeaveRecord]

    let date: Date
    let attendanceDay: AttendanceDay?

    @State private var selectedStatus: AttendanceClassification
    @State private var selectedReason: OverrideReason
    @State private var note: String
    @State private var saveError: String?

    private let calendar = Calendar.workTrackCalendar

    private static let editableStatuses: [AttendanceClassification] = [
        .office,
        .home,
        .mixed,
        .annualLeave,
        .sickLeave,
        .unknown
    ]

    init(date: Date, attendanceDay: AttendanceDay?) {
        self.date = date
        self.attendanceDay = attendanceDay

        let initialStatus = attendanceDay?.manualClassification ?? attendanceDay?.finalClassification ?? .unknown
        let initialNote = attendanceDay?.note ?? ""

        _selectedStatus = State(initialValue: initialStatus)
        _selectedReason = State(initialValue: .manualCorrection)
        _note = State(initialValue: initialNote)
    }

    private var detectedStatus: AttendanceClassification {
        attendanceDay?.detectedClassification ?? .unknown
    }

    private var finalStatus: AttendanceClassification {
        selectedStatus
    }

    private var requiresOverrideReason: Bool {
        finalStatus != detectedStatus
    }

    private var existingManualAdjustment: ManualAdjustment? {
        guard let attendanceDay else {
            return nil
        }

        return manualAdjustments.first { adjustment in
            adjustment.attendanceDayId == attendanceDay.id
        }
    }

    var body: some View {
        Form {
            Section("Day") {
                LabeledContent("Date", value: date.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                LabeledContent("Detected status", value: detectedStatus.displayName)
                LabeledContent("Final status", value: finalStatus.displayName)
            }

            if let attendanceDay {
                Section("Attendance") {
                    LabeledContent("Office minutes", value: attendanceDay.officeMinutes.formatted())
                    LabeledContent("Home minutes", value: attendanceDay.homeMinutes.formatted())
                    LabeledContent("Compliance", value: attendanceDay.complianceTreatment?.displayName ?? ComplianceTreatment.requiresReview.displayName)
                }
            }

            Section("Manual status") {
                Picker("Final status", selection: $selectedStatus) {
                    ForEach(Self.editableStatuses) { status in
                        Text(status.displayName)
                            .tag(status)
                    }
                }

                if requiresOverrideReason {
                    Picker("Override reason", selection: $selectedReason) {
                        ForEach(OverrideReason.allCases) { reason in
                            Text(reason.displayName)
                                .tag(reason)
                        }
                    }
                }
            }

            Section("Note") {
                TextEditor(text: $note)
                    .frame(minHeight: 120)
                    .accessibilityLabel("Attendance note")

                Text("Notes are explanatory only unless saved with a manual status or leave status.")
                    .font(AppTypography.caption)
                    .foregroundStyle(Color.ds.textSecondary)
            }

            if let saveError {
                Section {
                    Text(saveError)
                        .foregroundStyle(Color.ds.critical)
                }
            }
        }
        .navigationTitle(date.formatted(.dateTime.day().month(.wide)))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveChanges()
                }
            }
        }
        .onAppear {
            if let reason = existingManualAdjustment?.reason {
                selectedReason = reason
            }
        }
    }

    private func saveChanges() {
        let day = attendanceDay ?? AttendanceDay(
            date: calendar.startOfDay(for: date),
            detectedClassification: .unknown,
            finalClassification: .unknown
        )

        if attendanceDay == nil {
            modelContext.insert(day)
        }

        day.applyManualEdit(finalClassification: selectedStatus, note: note)
        upsertManualAdjustment(for: day)
        syncLeaveRecord()

        do {
            try modelContext.save()
            dismiss()
        } catch {
            saveError = "Changes could not be saved. Try again."
        }
    }

    private func upsertManualAdjustment(for day: AttendanceDay) {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        guard selectedStatus != (day.detectedClassification ?? .unknown) else {
            if let existingAdjustment = manualAdjustments.first(where: { $0.attendanceDayId == day.id }) {
                modelContext.delete(existingAdjustment)
            }
            return
        }

        if let existingAdjustment = manualAdjustments.first(where: { $0.attendanceDayId == day.id }) {
            existingAdjustment.adjustedClassificationRaw = selectedStatus.rawValue
            existingAdjustment.reasonRaw = selectedReason.rawValue
            existingAdjustment.note = trimmedNote.isEmpty ? nil : trimmedNote
            existingAdjustment.updatedAt = .now
        } else {
            let adjustment = ManualAdjustment(
                attendanceDayId: day.id,
                adjustedClassification: selectedStatus,
                reason: selectedReason,
                note: trimmedNote.isEmpty ? nil : trimmedNote
            )
            modelContext.insert(adjustment)
        }
    }

    private func syncLeaveRecord() {
        let dayStart = calendar.startOfDay(for: date)
        let existingLeaveRecord = leaveRecords.first { leaveRecord in
            calendar.isDate(leaveRecord.date, inSameDayAs: dayStart)
        }
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let selectedLeaveType = selectedStatus.leaveType else {
            if let existingLeaveRecord {
                modelContext.delete(existingLeaveRecord)
            }
            return
        }

        if let existingLeaveRecord {
            existingLeaveRecord.leaveTypeRaw = selectedLeaveType.rawValue
            existingLeaveRecord.durationRaw = LeaveDuration.fullDay.rawValue
            existingLeaveRecord.note = trimmedNote.isEmpty ? nil : trimmedNote
            existingLeaveRecord.updatedAt = .now
        } else {
            let leaveRecord = LeaveRecord(
                date: dayStart,
                leaveType: selectedLeaveType,
                duration: .fullDay,
                note: trimmedNote.isEmpty ? nil : trimmedNote
            )
            modelContext.insert(leaveRecord)
        }
    }
}

private extension AttendanceClassification {
    var leaveType: LeaveType? {
        switch self {
        case .annualLeave:
            .annualLeave
        case .sickLeave:
            .sickLeave
        case .office, .home, .mixed, .publicHoliday, .weekend, .nonWorkingDay, .unknown:
            nil
        }
    }

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
