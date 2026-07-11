import SwiftData
import SwiftUI

struct BatchLeaveView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AttendanceDay.date) private var attendanceDays: [AttendanceDay]
    @Query(sort: \LeaveRecord.date) private var leaveRecords: [LeaveRecord]
    @Query(sort: \ManualAdjustment.updatedAt) private var manualAdjustments: [ManualAdjustment]
    @Query(sort: \PublicHoliday.date) private var publicHolidays: [PublicHoliday]
    @Query(sort: \ComplianceRule.createdAt) private var complianceRules: [ComplianceRule]

    let displayedMonth: Date

    @State private var startDate: Date
    @State private var endDate: Date
    @State private var selectedLeaveType: LeaveType = .annualLeave
    @State private var note = ""
    @State private var saveError: String?

    private let calendar = Calendar.workTrackCalendar

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

        let updatedDescription = "\(affectedDates.count) "
            + "workday\(affectedDates.count == 1 ? "" : "s") will be updated."
        let skippedDescription = "\(skippedDatesCount) non-working or holiday "
            + "date\(skippedDatesCount == 1 ? "" : "s") skipped."
        return "\(updatedDescription) \(skippedDescription)"
    }

    init(displayedMonth: Date) {
        self.displayedMonth = displayedMonth
        _startDate = State(initialValue: displayedMonth)
        _endDate = State(initialValue: displayedMonth)
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
        let attendanceByDate = Dictionary(grouping: attendanceDays) {
            calendar.startOfDay(for: $0.date)
        }
        let leaveByDate = Dictionary(grouping: leaveRecords) {
            calendar.startOfDay(for: $0.date)
        }
        let today = calendar.startOfDay(for: .now)

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

            guard date <= today else {
                continue
            }

            let day = attendanceByDate[date]?.first ?? AttendanceDay(
                date: date,
                detectedClassification: .unknown,
                finalClassification: .unknown
            )

            if attendanceByDate[date] == nil {
                modelContext.insert(day)
            }

            day.applyManualEdit(
                finalClassification: selectedLeaveType.classification,
                note: trimmedNote,
                isManualOverride: false
            )
            day.complianceTreatmentRaw = ComplianceTreatment.excludedFromRequirement.rawValue

            manualAdjustments
                .filter { $0.attendanceDayId == day.id }
                .forEach(modelContext.delete)
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
