import SwiftData
import SwiftUI

struct MonthCalendarView: View {
    @Query(sort: \AttendanceDay.date) private var attendanceDays: [AttendanceDay]
    @Query(sort: \LeaveRecord.date) private var leaveRecords: [LeaveRecord]
    @State private var displayedMonth = Date.now
    @State private var isShowingBatchLeave = false

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
        let leaveByDay = Dictionary(grouping: leaveRecords) { leaveRecord in
            calendar.startOfDay(for: leaveRecord.date)
        }

        let blankDays = (0..<leadingBlanks).map { _ in CalendarDay(date: nil, attendanceDay: nil, leaveRecord: nil) }
        let populatedDays = monthDates.map { date in
            CalendarDay(
                date: date,
                attendanceDay: attendanceByDay[date]?.first,
                leaveRecord: leaveByDay[date]?.first
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
                    .frame(width: 40, height: 40)
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
                    .frame(width: 40, height: 40)
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
                LegendPill(text: "Review", token: "?", color: Color.ds.warning)
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
                            leaveRecord: day.leaveRecord
                        )
                    } label: {
                        DayCell(
                            date: date,
                            attendanceDay: day.attendanceDay,
                            leaveRecord: day.leaveRecord,
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

private struct BatchLeaveView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AttendanceDay.date) private var attendanceDays: [AttendanceDay]
    @Query(sort: \LeaveRecord.date) private var leaveRecords: [LeaveRecord]
    @Query(sort: \PublicHoliday.date) private var publicHolidays: [PublicHoliday]
    @Query(sort: \ComplianceRule.createdAt) private var complianceRules: [ComplianceRule]

    let displayedMonth: Date

    @State private var startDate: Date
    @State private var endDate: Date
    @State private var selectedLeaveType: LeaveType = .annualLeave
    @State private var note = ""
    @State private var saveError: String?

    private let calendar = Calendar.workTrackCalendar

    init(displayedMonth: Date) {
        self.displayedMonth = displayedMonth
        _startDate = State(initialValue: displayedMonth)
        _endDate = State(initialValue: displayedMonth)
    }

    private var activeRule: ComplianceRule {
        complianceRules.first ?? ComplianceRule()
    }

    private var selectedISOWeekdays: Set<Int> {
        Set(activeRule.selectedISOWeekdays)
    }

    private var normalizedRange: (start: Date, end: Date) {
        let normalizedStart = calendar.startOfDay(for: startDate)
        let normalizedEnd = calendar.startOfDay(for: endDate)

        if normalizedStart <= normalizedEnd {
            return (normalizedStart, normalizedEnd)
        }

        return (normalizedEnd, normalizedStart)
    }

    private var publicHolidayDates: Set<Date> {
        Set(
            publicHolidays.compactMap { publicHoliday in
                guard publicHoliday.jurisdictionId == activeRule.jurisdictionId else {
                    return nil
                }

                return calendar.startOfDay(for: publicHoliday.date)
            }
        )
    }

    private var candidateDates: [Date] {
        dates(from: normalizedRange.start, through: normalizedRange.end)
    }

    private var affectedDates: [Date] {
        candidateDates.filter { date in
            selectedISOWeekdays.contains(calendar.isoWeekday(for: date))
                && !publicHolidayDates.contains(date)
        }
    }

    private var skippedDatesCount: Int {
        candidateDates.count - affectedDates.count
    }

    private var bodySubtitle: String {
        if affectedDates.isEmpty {
            return "No eligible workdays in this range."
        }

        return "\(affectedDates.count) workday\(affectedDates.count == 1 ? "" : "s") will be updated. \(skippedDatesCount) non-working or holiday date\(skippedDatesCount == 1 ? "" : "s") skipped."
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Range") {
                    DatePicker("Start", selection: $startDate, displayedComponents: .date)
                    DatePicker("End", selection: $endDate, displayedComponents: .date)
                }

                Section("Leave") {
                    Picker("Type", selection: $selectedLeaveType) {
                        ForEach(LeaveType.allCases) { leaveType in
                            Text(leaveType.displayName)
                                .tag(leaveType)
                        }
                    }

                    LabeledContent("Duration", value: LeaveDuration.fullDay.displayName)
                }

                Section("Preview") {
                    LabeledContent("Affected days", value: affectedDates.count.formatted())
                    LabeledContent("Skipped days", value: skippedDatesCount.formatted())

                    Text(bodySubtitle)
                        .font(AppTypography.caption)
                        .foregroundStyle(Color.ds.textSecondary)
                }

                Section("Note") {
                    TextEditor(text: $note)
                        .frame(minHeight: 96)
                        .accessibilityLabel("Batch leave note")
                }

                if let saveError {
                    Section {
                        Text(saveError)
                            .foregroundStyle(Color.ds.critical)
                    }
                }
            }
            .navigationTitle("Batch Leave")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        applyBatchLeave()
                    }
                    .disabled(affectedDates.isEmpty)
                }
            }
        }
    }

    private func applyBatchLeave() {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let attendanceByDate = Dictionary(grouping: attendanceDays) { calendar.startOfDay(for: $0.date) }
        let leaveByDate = Dictionary(grouping: leaveRecords) { calendar.startOfDay(for: $0.date) }

        for date in affectedDates {
            if let existingLeaveRecord = leaveByDate[date]?.first {
                existingLeaveRecord.leaveTypeRaw = selectedLeaveType.rawValue
                existingLeaveRecord.durationRaw = LeaveDuration.fullDay.rawValue
                existingLeaveRecord.note = trimmedNote.isEmpty ? nil : trimmedNote
                existingLeaveRecord.updatedAt = .now
            } else {
                let leaveRecord = LeaveRecord(
                    date: date,
                    leaveType: selectedLeaveType,
                    duration: .fullDay,
                    note: trimmedNote.isEmpty ? nil : trimmedNote
                )
                modelContext.insert(leaveRecord)
            }

            let day = attendanceByDate[date]?.first ?? AttendanceDay(
                date: date,
                detectedClassification: .unknown,
                finalClassification: .unknown
            )

            if attendanceByDate[date] == nil {
                modelContext.insert(day)
            }

            day.applyManualEdit(finalClassification: selectedLeaveType.classification, note: trimmedNote)
            day.complianceTreatmentRaw = ComplianceTreatment.excludedFromRequirement.rawValue
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            saveError = "Batch leave could not be saved. Try again."
        }
    }

    private func dates(from start: Date, through end: Date) -> [Date] {
        var dates: [Date] = []
        var currentDate = calendar.startOfDay(for: start)
        let finalDate = calendar.startOfDay(for: end)

        while currentDate <= finalDate {
            dates.append(currentDate)

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }

        return dates
    }
}

private struct LegendPill: View {
    let text: String
    let token: String
    let color: Color

    var body: some View {
        HStack(spacing: AppSpacing.xxs) {
            Text(token)
                .font(.caption2.weight(.bold))
                .foregroundStyle(color)
                .frame(minWidth: 24, minHeight: 20)
                .background(color.opacity(0.12), in: Capsule(style: .continuous))

            Text(text)
                .font(AppTypography.captionStrong)
                .foregroundStyle(Color.ds.textSecondary)
        }
        .padding(.horizontal, AppSpacing.xs)
        .padding(.vertical, AppSpacing.xxs)
        .background(Color.ds.surfacePrimary.opacity(0.72), in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .stroke(Color.ds.borderSubtle.opacity(0.64), lineWidth: 1)
        }
    }
}

private struct CalendarDay: Identifiable {
    let id = UUID()
    let date: Date?
    let attendanceDay: AttendanceDay?
    let leaveRecord: LeaveRecord?
}

private struct DayCell: View {
    let date: Date
    let attendanceDay: AttendanceDay?
    let leaveRecord: LeaveRecord?
    let calendar: Calendar

    private var dayNumber: Int {
        calendar.component(.day, from: date)
    }

    private var status: AttendanceClassification {
        attendanceDay?.finalClassification ?? .unknown
    }

    private var leaveType: LeaveType? {
        leaveRecord?.leaveType ?? status.leaveType
    }

    private var badgeText: String {
        leaveType?.calendarBadgeText ?? status.calendarBadgeText
    }

    private var badgeBackgroundColor: Color {
        badgeForegroundColor.opacity(0.12)
    }

    private var badgeForegroundColor: Color {
        leaveType == nil ? status.calendarBadgeForegroundColor : Color.ds.leaveDay
    }

    private var cellTint: Color {
        badgeForegroundColor
    }

    private var isToday: Bool {
        calendar.isDateInToday(date)
    }

    private var accessibilityStatus: String {
        leaveType?.displayName ?? status.displayName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xxs) {
                Text(dayNumber, format: .number)
                    .font(AppTypography.captionStrong.monospacedDigit())
                    .foregroundStyle(Color.ds.textPrimary)

                Spacer(minLength: 0)

                if isToday {
                    Circle()
                        .fill(Color.ds.accentPrimary)
                        .frame(width: 5, height: 5)
                        .accessibilityHidden(true)
                }
            }

            Spacer(minLength: 0)

            Text(badgeText)
                .font(.caption2.weight(.bold))
                .foregroundStyle(badgeForegroundColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 22)
                .background(badgeBackgroundColor, in: RoundedRectangle(cornerRadius: AppRadius.xs, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.xs, style: .continuous)
                        .stroke(badgeForegroundColor.opacity(0.16), lineWidth: 1)
                }
        }
        .padding(AppSpacing.xs)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)
        .background(Color.ds.surfacePrimary.opacity(0.74))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                .stroke(isToday ? Color.ds.accentPrimary.opacity(0.42) : cellTint.opacity(0.12), lineWidth: isToday ? 1.5 : 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(date.formatted(.dateTime.day().month(.wide))), \(accessibilityStatus)")
    }
}

private struct DayDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ManualAdjustment.updatedAt, order: .reverse) private var manualAdjustments: [ManualAdjustment]
    @Query(sort: \LeaveRecord.date) private var leaveRecords: [LeaveRecord]
    @Query(sort: \PublicHoliday.date) private var publicHolidays: [PublicHoliday]
    @Query(sort: \ComplianceRule.createdAt) private var complianceRules: [ComplianceRule]

    let date: Date
    let attendanceDay: AttendanceDay?
    let leaveRecord: LeaveRecord?

    @State private var selectedStatus: AttendanceClassification
    @State private var selectedLeave: LeaveSelection
    @State private var selectedReason: OverrideReason
    @State private var note: String
    @State private var saveError: String?

    private let calendar = Calendar.workTrackCalendar

    private static let editableStatuses: [AttendanceClassification] = [
        .office,
        .home,
        .mixed,
        .unknown
    ]

    init(date: Date, attendanceDay: AttendanceDay?, leaveRecord: LeaveRecord?) {
        self.date = date
        self.attendanceDay = attendanceDay
        self.leaveRecord = leaveRecord

        let initialFinalStatus = attendanceDay?.manualClassification ?? attendanceDay?.finalClassification ?? .unknown
        let detectedStatus = attendanceDay?.detectedClassification ?? .unknown
        let initialStatus = Self.editableStatuses.contains(initialFinalStatus)
            ? initialFinalStatus
            : Self.editableStatuses.contains(detectedStatus) ? detectedStatus : .unknown
        let initialLeaveType = leaveRecord?.leaveType ?? initialFinalStatus.leaveType
        let initialNote = attendanceDay?.note ?? leaveRecord?.note ?? ""

        _selectedStatus = State(initialValue: initialStatus)
        _selectedLeave = State(initialValue: LeaveSelection(leaveType: initialLeaveType))
        _selectedReason = State(initialValue: .manualCorrection)
        _note = State(initialValue: initialNote)
    }

    private var detectedStatus: AttendanceClassification {
        attendanceDay?.detectedClassification ?? .unknown
    }

    private var finalStatus: AttendanceClassification {
        selectedLeave.leaveType?.classification ?? selectedStatus
    }

    private var requiresOverrideReason: Bool {
        selectedLeave == .none && finalStatus != detectedStatus
    }

    private var existingManualAdjustment: ManualAdjustment? {
        guard let attendanceDay else {
            return nil
        }

        return manualAdjustments.first { adjustment in
            adjustment.attendanceDayId == attendanceDay.id
        }
    }

    private var existingLeaveRecord: LeaveRecord? {
        leaveRecords.first { leaveRecord in
            calendar.isDate(leaveRecord.date, inSameDayAs: date)
        } ?? leaveRecord
    }

    private var selectedISOWeekdays: Set<Int> {
        Set(complianceRules.first?.selectedISOWeekdays ?? [1, 2, 3, 4, 5])
    }

    private var isPublicHoliday: Bool {
        publicHolidays.contains { publicHoliday in
            calendar.isDate(publicHoliday.date, inSameDayAs: date)
        }
    }

    private var isSelectedWorkday: Bool {
        selectedISOWeekdays.contains(calendar.isoWeekday(for: date))
    }

    private var leaveReducesEligibleDay: Bool {
        selectedLeave.leaveType != nil && isSelectedWorkday && !isPublicHoliday
    }

    private var eligibleDayImpactText: String {
        leaveReducesEligibleDay ? "1.0 day" : "0.0 days"
    }

    private var eligibleDayImpactReason: String {
        if selectedLeave.leaveType == nil {
            return "No leave recorded."
        }

        if isPublicHoliday {
            return "Public holidays are already excluded."
        }

        if !isSelectedWorkday {
            return "Non-workdays are not eligible compliance days."
        }

        return "Full-day leave excludes this eligible workday."
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                DSCard(includesShadow: false) {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        HStack(alignment: .top, spacing: AppSpacing.md) {
                            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                Text(date.formatted(.dateTime.weekday(.wide)))
                                    .font(AppTypography.captionStrong)
                                    .foregroundStyle(Color.ds.textSecondary)

                                Text(date.formatted(.dateTime.day().month(.wide).year()))
                                    .font(AppTypography.title)
                                    .foregroundStyle(Color.ds.textPrimary)
                                    .lineLimit(2)
                            }

                            Spacer(minLength: AppSpacing.sm)

                            DSStatusPill(
                                text: finalStatus.displayName,
                                systemImage: "checkmark.circle.fill",
                                style: statusPillStyle(for: finalStatus)
                            )
                        }

                        Divider()
                            .overlay(Color.ds.separator)

                        VStack(spacing: AppSpacing.sm) {
                            DetailInfoRow(title: "Detected", value: detectedStatus.displayName, color: detectedStatus.calendarBadgeForegroundColor)
                            DetailInfoRow(title: "Final", value: finalStatus.displayName, color: finalStatus.calendarBadgeForegroundColor)
                            DetailInfoRow(title: "Treatment", value: complianceTreatment(for: finalStatus).displayName, color: finalStatus.calendarBadgeForegroundColor)
                        }
                    }
                }

                DSCard(includesShadow: false) {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("Manual status")
                            .font(AppTypography.cardTitle)
                            .foregroundStyle(Color.ds.textPrimary)

                        Picker("Final status", selection: $selectedStatus) {
                            ForEach(Self.editableStatuses) { status in
                                Text(status.displayName)
                                    .tag(status)
                            }
                        }
                        .pickerStyle(.segmented)
                        .disabled(selectedLeave.leaveType != nil)

                        if requiresOverrideReason {
                            Picker("Override reason", selection: $selectedReason) {
                                ForEach(OverrideReason.allCases) { reason in
                                    Text(reason.displayName)
                                        .tag(reason)
                                }
                            }
                        }
                    }
                }

                DSCard(includesShadow: false) {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("Leave")
                            .font(AppTypography.cardTitle)
                            .foregroundStyle(Color.ds.textPrimary)

                        Picker("Full-day leave", selection: $selectedLeave) {
                            ForEach(LeaveSelection.allCases) { selection in
                                Text(selection.displayName)
                                    .tag(selection)
                            }
                        }
                        .pickerStyle(.segmented)

                        if selectedLeave.leaveType != nil {
                            DetailInfoRow(title: "Duration", value: LeaveDuration.fullDay.displayName, color: Color.ds.leaveDay)
                        }

                        DetailInfoRow(title: "Eligible impact", value: eligibleDayImpactText, color: leaveReducesEligibleDay ? Color.ds.leaveDay : Color.ds.textTertiary)

                        Text(eligibleDayImpactReason)
                            .font(AppTypography.caption)
                            .foregroundStyle(Color.ds.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let attendanceDay {
                    DSCard(includesShadow: false) {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Text("Attendance")
                                .font(AppTypography.cardTitle)
                                .foregroundStyle(Color.ds.textPrimary)

                            DetailInfoRow(title: "Office minutes", value: attendanceDay.officeMinutes.formatted(), color: Color.ds.officeDay)
                            DetailInfoRow(title: "Home minutes", value: attendanceDay.homeMinutes.formatted(), color: Color.ds.homeDay)
                            DetailInfoRow(title: "Compliance", value: attendanceDay.complianceTreatment?.displayName ?? ComplianceTreatment.requiresReview.displayName, color: Color.ds.info)
                        }
                    }
                }

                DSCard(includesShadow: false) {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("Note")
                            .font(AppTypography.cardTitle)
                            .foregroundStyle(Color.ds.textPrimary)

                        TextEditor(text: $note)
                            .frame(minHeight: 120)
                            .padding(AppSpacing.xs)
                            .background(Color.ds.surfaceSecondary.opacity(0.62), in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
                            .accessibilityLabel("Attendance note")

                        Text("Notes are explanatory only unless saved with a manual status or leave status.")
                            .font(AppTypography.caption)
                            .foregroundStyle(Color.ds.textSecondary)
                    }
                }

                if let saveError {
                    DSInsightCallout(
                        icon: "exclamationmark.triangle",
                        message: saveError,
                        highlightedText: "Changes could not be saved"
                    )
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.vertical, AppSpacing.lg)
        }
        .appScreenBackground()
        .navigationTitle(date.formatted(.dateTime.day().month(.wide)))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveChanges()
                }
                .buttonStyle(.glassProminent)
            }
        }
        .onAppear {
            if let reason = existingManualAdjustment?.reason {
                selectedReason = reason
            }
        }
    }

    private func statusPillStyle(for status: AttendanceClassification) -> DSStatusPillStyle {
        switch status {
        case .office:
            .success
        case .mixed, .unknown:
            .warning
        case .home, .annualLeave, .sickLeave, .publicHoliday, .weekend, .nonWorkingDay:
            .neutral
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

        day.applyManualEdit(finalClassification: finalStatus, note: note)
        day.complianceTreatmentRaw = complianceTreatment(for: finalStatus).rawValue
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

        guard selectedLeave == .none else {
            if let existingAdjustment = manualAdjustments.first(where: { $0.attendanceDayId == day.id }) {
                modelContext.delete(existingAdjustment)
            }
            return
        }

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
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let selectedLeaveType = selectedLeave.leaveType else {
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

    private func complianceTreatment(for status: AttendanceClassification) -> ComplianceTreatment {
        switch status {
        case .office:
            .countsAsOffice
        case .home, .mixed:
            .countsAsHome
        case .annualLeave, .sickLeave, .publicHoliday, .weekend, .nonWorkingDay:
            .excludedFromRequirement
        case .unknown:
            .requiresReview
        }
    }
}

private struct DetailInfoRow: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.callout)
                .foregroundStyle(Color.ds.textSecondary)

            Spacer(minLength: AppSpacing.sm)

            Text(value)
                .font(AppTypography.callout.weight(.semibold))
                .foregroundStyle(color)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
    }
}

private enum LeaveSelection: String, CaseIterable, Identifiable {
    case none
    case annualLeave
    case sickLeave

    var id: String { rawValue }

    init(leaveType: LeaveType?) {
        switch leaveType {
        case .annualLeave:
            self = .annualLeave
        case .sickLeave:
            self = .sickLeave
        case nil:
            self = .none
        }
    }

    var displayName: String {
        switch self {
        case .none:
            "None"
        case .annualLeave:
            LeaveType.annualLeave.displayName
        case .sickLeave:
            LeaveType.sickLeave.displayName
        }
    }

    var leaveType: LeaveType? {
        switch self {
        case .none:
            nil
        case .annualLeave:
            .annualLeave
        case .sickLeave:
            .sickLeave
        }
    }
}

private extension LeaveType {
    var classification: AttendanceClassification {
        switch self {
        case .annualLeave:
            .annualLeave
        case .sickLeave:
            .sickLeave
        }
    }

    var calendarBadgeText: String {
        switch self {
        case .annualLeave:
            "AL"
        case .sickLeave:
            "SL"
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

    func isoWeekday(for date: Date) -> Int {
        let weekday = component(.weekday, from: date)
        return weekday == 1 ? 7 : weekday - 1
    }
}

#Preview {
    MonthCalendarView()
        .modelContainer(PreviewData.modelContainer())
}
