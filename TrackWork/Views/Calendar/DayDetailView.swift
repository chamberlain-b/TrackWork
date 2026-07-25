import SwiftData
import SwiftUI

struct DayDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ManualAdjustment.updatedAt, order: .reverse)
    private var manualAdjustments: [ManualAdjustment]
    @Query(sort: \LeaveRecord.date) private var leaveRecords: [LeaveRecord]
    @Query(sort: \PublicHoliday.date) private var publicHolidays: [PublicHoliday]
    @Query(sort: \CustomExcludedDay.date) private var customExcludedDays: [CustomExcludedDay]
    @Query(sort: \PlannedOfficeDay.date) private var plannedOfficeDays: [PlannedOfficeDay]
    @Query(sort: \ComplianceRule.createdAt) private var complianceRules: [ComplianceRule]

    let date: Date
    let attendanceDay: AttendanceDay?
    let leaveRecord: LeaveRecord?
    let publicHoliday: PublicHoliday?
    let customExcludedDay: CustomExcludedDay?

    @State private var selectedStatus: AttendanceClassification
    @State private var selectedLeave: LeaveSelection
    @State private var selectedReason: OverrideReason
    @State private var note: String
    @State private var isCustomExcluded: Bool
    @State private var customExclusionReason: String
    @State private var saveError: String?

    private let calendar = Calendar.workTrackCalendar
    private let ruleResolver = ComplianceRuleResolver()

    private var activeRule: ComplianceRule {
        ruleResolver.rule(for: date, from: complianceRules) ?? ComplianceRule()
    }

    private var detectedStatus: AttendanceClassification {
        attendanceDay?.detectedClassification ?? .unknown
    }

    private var finalStatus: AttendanceClassification {
        if activePublicHoliday != nil {
            return .publicHoliday
        }

        if isCustomExcluded {
            return .nonWorkingDay
        }

        if let leaveStatus = selectedLeave.leaveType?.classification {
            return leaveStatus
        }

        return isFutureDate ? .unknown : selectedStatus
    }

    private var isFutureDate: Bool {
        calendar.startOfDay(for: date) > calendar.startOfDay(for: .now)
    }

    private var canSave: Bool {
        !isFutureDate
            || selectedLeave != .none
            || existingLeaveRecord != nil
            || isCustomExcluded
            || existingCustomExcludedDay != nil
    }

    private var requiresOverrideReason: Bool {
        selectedLeave == .none
            && !isCustomExcluded
            && activePublicHoliday == nil
            && finalStatus != detectedStatus
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

    private var existingCustomExcludedDay: CustomExcludedDay? {
        customExcludedDays.first { excludedDay in
            calendar.isDate(excludedDay.date, inSameDayAs: date)
        } ?? customExcludedDay
    }

    private var selectedISOWeekdays: Set<Int> {
        Set(activeRule.selectedISOWeekdays)
    }

    private var activeJurisdictionId: String {
        activeRule.jurisdictionId
    }

    private var activePublicHoliday: PublicHoliday? {
        var availableHolidays = publicHolidays
        if let publicHoliday {
            availableHolidays.append(publicHoliday)
        }

        return ActiveJurisdictionHolidayResolver.holiday(
            on: date,
            from: availableHolidays,
            jurisdictionId: activeJurisdictionId,
            calendar: calendar
        )
    }

    private var isPublicHoliday: Bool {
        activePublicHoliday != nil
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

    private var customExclusionReducesEligibleDay: Bool {
        isCustomExcluded && selectedLeave == .none && isSelectedWorkday && !isPublicHoliday
    }

    private var customExclusionImpactText: String {
        customExclusionReducesEligibleDay ? "1.0 day" : "0.0 days"
    }

    private var customExclusionImpactReason: String {
        if isPublicHoliday {
            return "Public holidays are already excluded."
        }

        if selectedLeave != .none {
            return "Full-day leave already excludes this date."
        }

        if !isSelectedWorkday {
            return "Non-workdays are not eligible compliance days."
        }

        return "Excluded from eligible workdays."
    }

    init(
        date: Date,
        attendanceDay: AttendanceDay?,
        leaveRecord: LeaveRecord?,
        publicHoliday: PublicHoliday?,
        customExcludedDay: CustomExcludedDay?,
        proposedStatus: AttendanceClassification? = nil
    ) {
        self.date = date
        self.attendanceDay = attendanceDay
        self.leaveRecord = leaveRecord
        self.publicHoliday = publicHoliday
        self.customExcludedDay = customExcludedDay

        let initialFinalStatus = proposedStatus
            ?? attendanceDay?.manualClassification
            ?? attendanceDay?.finalClassification
            ?? .unknown
        let detectedStatus = attendanceDay?.detectedClassification ?? .unknown
        let initialStatus = DayDetailStatusOptions.editable.contains(initialFinalStatus)
            ? initialFinalStatus
            : DayDetailStatusOptions.editable.contains(detectedStatus) ? detectedStatus : .unknown
        let initialLeaveType = proposedStatus?.leaveType ?? leaveRecord?.leaveType ?? initialFinalStatus.leaveType
        let initialNote = attendanceDay?.note ?? leaveRecord?.note ?? ""

        _selectedStatus = State(initialValue: initialStatus)
        _selectedLeave = State(initialValue: LeaveSelection(leaveType: initialLeaveType))
        _selectedReason = State(initialValue: .manualCorrection)
        _note = State(initialValue: initialNote)
        _isCustomExcluded = State(initialValue: customExcludedDay != nil)
        _customExclusionReason = State(initialValue: customExcludedDay?.reason ?? "")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                DayDetailHeaderCard(
                    date: date,
                    detectedStatus: detectedStatus,
                    finalStatus: finalStatus,
                    isUpcoming: isFutureDate
                        && selectedLeave == .none
                        && !isCustomExcluded
                        && activePublicHoliday == nil,
                    complianceTreatment: complianceTreatment(for: finalStatus)
                )

                if let activePublicHoliday {
                    DayDetailHolidayCard(holiday: activePublicHoliday)
                }

                if isFutureDate {
                    DSInsightCallout(
                        icon: "calendar.badge.plus",
                        message: futureDateMessage,
                        highlightedText: "Future date"
                    )
                } else {
                    DayDetailManualStatusCard(
                        selectedStatus: $selectedStatus,
                        selectedReason: $selectedReason,
                        isLeaveSelected: selectedLeave.leaveType != nil
                            || isCustomExcluded
                            || activePublicHoliday != nil,
                        requiresOverrideReason: requiresOverrideReason
                    )
                }

                DayDetailLeaveCard(
                    selectedLeave: $selectedLeave,
                    eligibleDayImpactText: eligibleDayImpactText,
                    eligibleDayImpactReason: eligibleDayImpactReason,
                    leaveReducesEligibleDay: leaveReducesEligibleDay
                )

                DayDetailCustomExclusionCard(
                    isExcluded: $isCustomExcluded,
                    reason: $customExclusionReason,
                    eligibleDayImpactText: customExclusionImpactText,
                    eligibleDayImpactReason: customExclusionImpactReason,
                    reducesEligibleDay: customExclusionReducesEligibleDay
                )

                if let attendanceDay, !isFutureDate {
                    DayDetailAttendanceCard(attendanceDay: attendanceDay)
                }

                if !isFutureDate
                    || selectedLeave != .none
                    || existingLeaveRecord != nil
                    || isCustomExcluded
                    || existingCustomExcludedDay != nil {
                    DayDetailNoteCard(note: $note)
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
                Button("Save", action: saveChanges)
                    .buttonStyle(.glassProminent)
                    .disabled(!canSave)
                    .accessibilityIdentifier("dayDetail.save")
            }
        }
        .onAppear(perform: loadExistingReason)
    }
}

private extension DayDetailView {
    var futureDateMessage: String {
        "Add full-day leave or an exclusion now. Attendance unlocks on the day."
    }

    func loadExistingReason() {
        if let reason = existingManualAdjustment?.reason {
            selectedReason = reason
        }
    }

    func saveChanges() {
        if isFutureDate {
            syncLeaveRecord()
            syncCustomExcludedDay()
            syncFutureAttendanceDay()
            removeOfficePlanForDate()
            saveModelContext()
            return
        }

        let day = attendanceDay ?? AttendanceDay(
            date: calendar.startOfDay(for: date),
            detectedClassification: .unknown,
            finalClassification: .unknown
        )

        if attendanceDay == nil {
            modelContext.insert(day)
        }

        day.applyManualEdit(
            finalClassification: finalStatus,
            note: note,
            isManualOverride: requiresOverrideReason
        )
        day.complianceTreatmentRaw = complianceTreatment(for: finalStatus).rawValue
        upsertManualAdjustment(for: day)
        syncLeaveRecord()
        syncCustomExcludedDay()
        removeOfficePlanForDate()

        saveModelContext()
    }

    func saveModelContext() {
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveError = "Changes could not be saved. Try again."
        }
    }

    func removeOfficePlanForDate() {
        plannedOfficeDays
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .forEach(modelContext.delete)
    }

    func upsertManualAdjustment(for day: AttendanceDay) {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        guard selectedLeave == .none, !isCustomExcluded, activePublicHoliday == nil else {
            deleteManualAdjustment(for: day)
            return
        }

        guard selectedStatus != (day.detectedClassification ?? .unknown) else {
            deleteManualAdjustment(for: day)
            return
        }

        if let existingAdjustment = manualAdjustment(for: day) {
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

    func deleteManualAdjustment(for day: AttendanceDay) {
        if let existingAdjustment = manualAdjustment(for: day) {
            modelContext.delete(existingAdjustment)
        }
    }

    func manualAdjustment(for day: AttendanceDay) -> ManualAdjustment? {
        manualAdjustments.first { adjustment in
            adjustment.attendanceDayId == day.id
        }
    }

    func syncLeaveRecord() {
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

    func syncCustomExcludedDay() {
        let dayStart = calendar.startOfDay(for: date)
        let trimmedReason = customExclusionReason.trimmingCharacters(in: .whitespacesAndNewlines)

        guard isCustomExcluded else {
            if let existingCustomExcludedDay {
                modelContext.delete(existingCustomExcludedDay)
            }
            return
        }

        if let existingCustomExcludedDay {
            existingCustomExcludedDay.date = dayStart
            existingCustomExcludedDay.reason = trimmedReason.isEmpty ? nil : trimmedReason
            existingCustomExcludedDay.updatedAt = .now
        } else {
            modelContext.insert(
                CustomExcludedDay(
                    date: dayStart,
                    reason: trimmedReason.isEmpty ? nil : trimmedReason
                )
            )
        }
    }

    func syncFutureAttendanceDay() {
        guard let attendanceDay else {
            return
        }

        if activePublicHoliday != nil {
            attendanceDay.applyManualEdit(
                finalClassification: .publicHoliday,
                note: note,
                isManualOverride: false
            )
            attendanceDay.complianceTreatmentRaw = ComplianceTreatment.excludedFromRequirement.rawValue
            return
        }

        if let leaveType = selectedLeave.leaveType {
            let classification = leaveType.classification
            attendanceDay.applyManualEdit(
                finalClassification: classification,
                note: note,
                isManualOverride: false
            )
            attendanceDay.complianceTreatmentRaw = ComplianceTreatment.excludedFromRequirement.rawValue
            return
        }

        if isCustomExcluded {
            attendanceDay.applyManualEdit(
                finalClassification: .nonWorkingDay,
                note: note,
                isManualOverride: false
            )
            attendanceDay.complianceTreatmentRaw = ComplianceTreatment.excludedFromRequirement.rawValue
            return
        }

        let detectedClassification = attendanceDay.detectedClassification ?? .unknown
        let isLeaveOnlyPlaceholder = detectedClassification == .unknown
            && attendanceDay.officeMinutes == 0
            && attendanceDay.homeMinutes == 0
            && attendanceDay.finalClassification?.leaveType != nil

        if isLeaveOnlyPlaceholder {
            modelContext.delete(attendanceDay)
            return
        }

        attendanceDay.applyManualEdit(
            finalClassification: detectedClassification,
            note: note,
            isManualOverride: false
        )
        attendanceDay.complianceTreatmentRaw = complianceTreatment(for: detectedClassification).rawValue
    }

    func complianceTreatment(for status: AttendanceClassification) -> ComplianceTreatment {
        ComplianceTreatmentResolver.resolve(
            classification: status,
            officeMinutes: attendanceDay?.officeMinutes ?? 0,
            minimumOfficeMinutes: activeRule.minimumOfficeMinutes
        )
    }
}
