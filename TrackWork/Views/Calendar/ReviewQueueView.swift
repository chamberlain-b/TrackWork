import SwiftData
import SwiftUI

struct ReviewQueueView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Query(sort: \AttendanceDay.date) private var attendanceDays: [AttendanceDay]
    @Query(sort: \LeaveRecord.date) private var leaveRecords: [LeaveRecord]
    @Query(sort: \PublicHoliday.date) private var publicHolidays: [PublicHoliday]
    @Query(sort: \CustomExcludedDay.date) private var customExcludedDays: [CustomExcludedDay]
    @Query(sort: \ComplianceRule.createdAt) private var complianceRules: [ComplianceRule]
    @Query(sort: \ManualAdjustment.updatedAt, order: .reverse)
    private var manualAdjustments: [ManualAdjustment]

    @State private var saveError: String?
    @State private var isSelecting = false
    @State private var selectedDates: Set<Date> = []
    @State private var pendingBatchClassification: AttendanceClassification?
    @State private var undoTransaction: ReviewUndoTransaction?

    private let referenceDate: Date
    private let calendar = Calendar.workTrackCalendar
    private let reviewCalculator = ReviewDateCalculator()
    private let ruleResolver = ComplianceRuleResolver()

    init(referenceDate: Date = .now) {
        self.referenceDate = referenceDate
    }

    private var range: ComplianceDateRange {
        ComplianceDateRange(
            start: calendar.complianceMonthStart(for: referenceDate),
            end: calendar.complianceMonthEnd(for: referenceDate),
            calendar: calendar
        )
    }

    private var activeRule: ComplianceRule {
        ruleResolver.rule(for: range.end, from: complianceRules) ?? ComplianceRule()
    }

    private var reviewDates: [Date] {
        reviewCalculator.datesNeedingReview(
            ReviewDateCalculator.Input(
                range: range,
                calendar: calendar,
                rule: activeRule,
                attendanceDays: attendanceDays,
                leaveRecords: leaveRecords,
                publicHolidays: publicHolidays,
                customExcludedDays: customExcludedDays,
                evaluationDate: referenceDate
            )
        )
    }

    var body: some View {
        List {
            if reviewDates.isEmpty {
                ContentUnavailableView(
                    "All caught up",
                    systemImage: "checkmark.circle",
                    description: Text("No days need review this month.")
                )
                .listRowBackground(Color.clear)
            } else if isSelecting {
                selectionContent
            } else {
                regularReviewContent
            }
        }
        .scrollContentBackground(.hidden)
        .appScreenBackground()
        .navigationTitle("Review Days")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if !reviewDates.isEmpty {
                    Button(isSelecting ? "Done" : "Select") {
                        isSelecting.toggle()
                        if !isSelecting {
                            selectedDates.removeAll()
                        }
                    }
                    .accessibilityIdentifier("reviewQueue.select")
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomControls
        }
        .confirmationDialog(
            batchConfirmationTitle,
            isPresented: Binding(
                get: { pendingBatchClassification != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingBatchClassification = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            if let classification = pendingBatchClassification {
                Button(batchConfirmationButtonTitle(for: classification)) {
                    let dates = selectedDates.sorted()
                    pendingBatchClassification = nil
                    apply(classification, to: dates)
                    selectedDates.removeAll()
                    isSelecting = false
                }
                .accessibilityIdentifier("reviewQueue.confirmBatch")
            }
            Button("Cancel", role: .cancel) {
                pendingBatchClassification = nil
            }
        } message: {
            Text(batchPreviewText)
        }
        .alert(
            "Couldn’t save attendance",
            isPresented: Binding(
                get: { saveError != nil },
                set: { isPresented in
                    if !isPresented {
                        saveError = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "Try again.")
        }
        .onChange(of: reviewDates) { _, newReviewDates in
            selectedDates.formIntersection(newReviewDates)
            if newReviewDates.isEmpty {
                isSelecting = false
            }
        }
    }

    @ViewBuilder
    private var regularReviewContent: some View {
        Section {
            if let firstDate = reviewDates.first {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            nextDateLabel(firstDate)
                            remainingLabel
                        }
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                            nextDateLabel(firstDate)

                            Spacer(minLength: AppSpacing.sm)

                            remainingLabel
                        }
                    }

                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(spacing: AppSpacing.sm) {
                            quickAction(
                                title: "Office",
                                systemImage: "building.2.fill",
                                classification: .office,
                                date: firstDate
                            )
                            quickAction(
                                title: "Home",
                                systemImage: "house.fill",
                                classification: .home,
                                date: firstDate
                            )
                        }
                    } else {
                        HStack(spacing: AppSpacing.sm) {
                            quickAction(
                                title: "Office",
                                systemImage: "building.2.fill",
                                classification: .office,
                                date: firstDate
                            )
                            quickAction(
                                title: "Home",
                                systemImage: "house.fill",
                                classification: .home,
                                date: firstDate
                            )
                        }
                    }
                }

                dayLink(for: firstDate) {
                    Label("Leave, notes or exclusions", systemImage: "ellipsis.circle")
                        .foregroundStyle(Color.ds.interactionPrimary)
                }
                .accessibilityIdentifier("reviewQueue.moreOptions")
            }
        } header: {
            Text("Next")
        }

        if reviewDates.count > 1 {
            Section("Later") {
                ForEach(Array(reviewDates.dropFirst()), id: \.self) { date in
                    dayLink(for: date) {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.ds.warning)
                                .accessibilityHidden(true)

                            Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                                .font(AppTypography.headline)
                        }
                        .padding(.vertical, AppSpacing.xxs)
                    }
                    .accessibilityIdentifier(calendar.calendarDayAccessibilityIdentifier(for: date))
                }
            }
        }
    }

    @ViewBuilder
    private var selectionContent: some View {
        Section {
            Button {
                selectedDates.formUnion(reviewDatesInFirstWeek)
            } label: {
                HStack {
                    Label("Review this week", systemImage: "calendar.badge.checkmark")
                    Spacer()
                    Text("\(reviewDatesInFirstWeek.count) days")
                        .foregroundStyle(Color.ds.textSecondary)
                }
            }
            .disabled(reviewDatesInFirstWeek.isEmpty)
            .accessibilityHint("Selects the review days in the first listed week")
            .accessibilityIdentifier("reviewQueue.selectWeek")
        } footer: {
            Text("Select only days you can confirm. Nothing changes until you approve the batch.")
        }

        Section("Days needing review") {
            ForEach(reviewDates, id: \.self) { date in
                selectionRow(for: date)
            }
        }
    }

    private func nextDateLabel(_ date: Date) -> some View {
        Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
            .font(AppTypography.headline)
    }

    private var remainingLabel: some View {
        Text("\(reviewDates.count) remaining")
            .font(AppTypography.captionStrong.monospacedDigit())
            .foregroundStyle(Color.ds.textSecondary)
            .accessibilityIdentifier("reviewQueue.remaining")
    }

    private func quickAction(
        title: String,
        systemImage: String,
        classification: AttendanceClassification,
        date: Date
    ) -> some View {
        Button {
            record(classification, on: date)
        } label: {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
                .foregroundStyle(Color.ds.textInverse)
        }
        .buttonStyle(.borderedProminent)
        .tint(classification == .office ? Color.ds.officeDay : Color.ds.homeDay)
        .controlSize(.large)
        .accessibilityIdentifier("reviewQueue.mark\(title)")
    }

    private func selectionRow(for date: Date) -> some View {
        let isSelected = selectedDates.contains(date)

        return Button {
            if isSelected {
                selectedDates.remove(date)
            } else {
                selectedDates.insert(date)
            }
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.ds.accentPrimary : Color.ds.textSecondary)
                    .accessibilityHidden(true)

                Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(AppTypography.headline)
                    .foregroundStyle(Color.ds.textPrimary)

                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.vertical, AppSpacing.xxs)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            date.formatted(.dateTime.weekday(.wide).day().month(.wide))
        )
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(
            "reviewQueue.selection.\(calendar.calendarDayAccessibilityIdentifier(for: date))"
        )
    }

    @ViewBuilder
    private var bottomControls: some View {
        if undoTransaction != nil || isSelecting {
            VStack(spacing: 0) {
                if let undoTransaction {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.ds.success)
                            .accessibilityHidden(true)

                        Text(undoTransaction.message)
                            .font(AppTypography.body)
                            .foregroundStyle(Color.ds.textPrimary)

                        Spacer(minLength: AppSpacing.sm)

                        Button("Undo") {
                            undoLastChange()
                        }
                        .font(AppTypography.headline)
                        .accessibilityIdentifier("reviewQueue.undo")
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.vertical, AppSpacing.sm)
                }

                if isSelecting {
                    Divider()

                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text(selectionSummary)
                            .font(AppTypography.caption)
                            .foregroundStyle(Color.ds.textSecondary)
                            .accessibilityIdentifier("reviewQueue.selectionSummary")

                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: AppSpacing.sm) {
                                batchAction(
                                    title: "Mark Office",
                                    systemImage: "building.2.fill",
                                    classification: .office
                                )
                                batchAction(
                                    title: "Mark Home",
                                    systemImage: "house.fill",
                                    classification: .home
                                )
                            }

                            VStack(spacing: AppSpacing.sm) {
                                batchAction(
                                    title: "Mark Office",
                                    systemImage: "building.2.fill",
                                    classification: .office
                                )
                                batchAction(
                                    title: "Mark Home",
                                    systemImage: "house.fill",
                                    classification: .home
                                )
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.vertical, AppSpacing.sm)
                }
            }
            .background(.bar)
        }
    }

    private func batchAction(
        title: String,
        systemImage: String,
        classification: AttendanceClassification
    ) -> some View {
        let isDisabled = selectedDates.isEmpty
        let tint = classification == .office ? Color.ds.officeDay : Color.ds.homeDay

        return Button {
            pendingBatchClassification = classification
        } label: {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .foregroundStyle(isDisabled ? Color.ds.textSecondary : Color.ds.textInverse)
                .background(
                    isDisabled ? Color.ds.surfaceSecondary : tint,
                    in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                )
                .overlay {
                    if isDisabled {
                        RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                            .stroke(Color.ds.borderSubtle, lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityIdentifier(
            classification == .office
                ? "reviewQueue.markSelectedOffice"
                : "reviewQueue.markSelectedHome"
        )
    }

    private func dayLink<Label: View>(
        for date: Date,
        @ViewBuilder label: () -> Label
    ) -> some View {
        NavigationLink {
            DayDetailView(
                date: date,
                attendanceDay: attendanceDay(on: date),
                leaveRecord: leaveRecord(on: date),
                publicHoliday: publicHoliday(on: date),
                customExcludedDay: customExcludedDay(on: date)
            )
        } label: {
            label()
        }
    }

    private func attendanceDay(on date: Date) -> AttendanceDay? {
        attendanceDays.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private func leaveRecord(on date: Date) -> LeaveRecord? {
        leaveRecords.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private func publicHoliday(on date: Date) -> PublicHoliday? {
        ActiveJurisdictionHolidayResolver.holiday(
            on: date,
            from: publicHolidays,
            jurisdictionId: activeRule.jurisdictionId,
            calendar: calendar
        )
    }

    private func customExcludedDay(on date: Date) -> CustomExcludedDay? {
        customExcludedDays.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private var reviewDatesInFirstWeek: [Date] {
        guard let firstDate = reviewDates.first,
              let week = calendar.dateInterval(of: .weekOfYear, for: firstDate) else {
            return []
        }
        return reviewDates.filter { week.contains($0) }
    }

    private var selectionSummary: String {
        let count = selectedDates.count
        return count == 1 ? "1 day selected" : "\(count) days selected"
    }

    private var batchConfirmationTitle: String {
        guard let classification = pendingBatchClassification else {
            return "Confirm selected days"
        }
        let title = classification == .office ? "Office" : "Home"
        return "Mark \(selectedDates.count) days as \(title)?"
    }

    private func batchConfirmationButtonTitle(
        for classification: AttendanceClassification
    ) -> String {
        let title = classification == .office ? "Office" : "Home"
        return "Mark as \(title)"
    }

    private var batchPreviewText: String {
        selectedDates
            .sorted()
            .map { $0.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)) }
            .joined(separator: ", ")
    }

}

private extension ReviewQueueView {
    func record(_ classification: AttendanceClassification, on date: Date) {
        apply(classification, to: [date])
    }

    func apply(_ classification: AttendanceClassification, to dates: [Date]) {
        guard !dates.isEmpty else {
            return
        }

        var undoEntries: [ReviewUndoEntry] = []

        for date in dates {
            let existingDay = attendanceDay(on: date)
            let day = existingDay ?? AttendanceDay(
                date: calendar.startOfDay(for: date),
                detectedClassification: .unknown,
                finalClassification: .unknown
            )
            let attendanceSnapshot: ReviewAttendanceSnapshot?
            if let existingDay {
                attendanceSnapshot = ReviewAttendanceSnapshot(existingDay)
            } else {
                attendanceSnapshot = nil
            }
            let adjustmentSnapshot: ReviewAdjustmentSnapshot?
            if let existingAdjustment = adjustment(for: day.id) {
                adjustmentSnapshot = ReviewAdjustmentSnapshot(existingAdjustment)
            } else {
                adjustmentSnapshot = nil
            }

            if existingDay == nil {
                modelContext.insert(day)
            }

            let detectedClassification = day.detectedClassification ?? .unknown
            let isManualOverride = detectedClassification != classification
            day.applyManualEdit(
                finalClassification: classification,
                note: day.note,
                isManualOverride: isManualOverride
            )
            day.complianceTreatmentRaw = ComplianceTreatmentResolver.resolve(
                classification: classification,
                officeMinutes: day.officeMinutes,
                minimumOfficeMinutes: activeRule.minimumOfficeMinutes
            ).rawValue
            let resultingAdjustment = syncManualAdjustment(
                for: day,
                classification: classification,
                isManualOverride: isManualOverride
            )
            undoEntries.append(
                ReviewUndoEntry(
                    day: day,
                    wasInserted: existingDay == nil,
                    attendanceSnapshot: attendanceSnapshot,
                    adjustmentSnapshot: adjustmentSnapshot,
                    resultingAdjustment: resultingAdjustment
                )
            )
        }

        do {
            try modelContext.save()
            let dayLabel = dates.count == 1 ? "day" : "days"
            undoTransaction = ReviewUndoTransaction(
                entries: undoEntries,
                message: "Marked \(dates.count) \(dayLabel) as \(classification.displayName)"
            )
            saveError = nil
        } catch {
            modelContext.rollback()
            saveError = "The day wasn’t changed. Try again."
        }
    }

    func syncManualAdjustment(
        for day: AttendanceDay,
        classification: AttendanceClassification,
        isManualOverride: Bool
    ) -> ManualAdjustment? {
        let existingAdjustment = adjustment(for: day.id)

        guard isManualOverride else {
            if let existingAdjustment {
                modelContext.delete(existingAdjustment)
            }
            return nil
        }

        if let existingAdjustment {
            existingAdjustment.adjustedClassificationRaw = classification.rawValue
            existingAdjustment.reasonRaw = OverrideReason.manualCorrection.rawValue
            existingAdjustment.updatedAt = .now
            return existingAdjustment
        } else {
            let adjustment = ManualAdjustment(
                attendanceDayId: day.id,
                adjustedClassification: classification,
                reason: .manualCorrection
            )
            modelContext.insert(adjustment)
            return adjustment
        }
    }

    func adjustment(for attendanceDayId: UUID) -> ManualAdjustment? {
        manualAdjustments.first { $0.attendanceDayId == attendanceDayId }
    }

    func undoLastChange() {
        guard let undoTransaction else {
            return
        }

        for entry in undoTransaction.entries.reversed() {
            if entry.wasInserted {
                if let currentAdjustment = entry.resultingAdjustment
                    ?? adjustment(for: entry.day.id) {
                    modelContext.delete(currentAdjustment)
                }
                modelContext.delete(entry.day)
                continue
            }

            entry.attendanceSnapshot?.restore(entry.day)
            restoreAdjustment(
                entry.adjustmentSnapshot,
                for: entry.day.id,
                currentAdjustment: entry.resultingAdjustment
            )
        }

        do {
            try modelContext.save()
            self.undoTransaction = nil
            saveError = nil
        } catch {
            modelContext.rollback()
            saveError = "The change couldn’t be undone. Try again."
        }
    }

    func restoreAdjustment(
        _ snapshot: ReviewAdjustmentSnapshot?,
        for attendanceDayId: UUID,
        currentAdjustment storedAdjustment: ManualAdjustment?
    ) {
        let currentAdjustment = storedAdjustment ?? adjustment(for: attendanceDayId)

        guard let snapshot else {
            if let currentAdjustment {
                modelContext.delete(currentAdjustment)
            }
            return
        }

        if let currentAdjustment {
            snapshot.restore(currentAdjustment)
            return
        }

        guard
            let classification = AttendanceClassification(
                rawValue: snapshot.adjustedClassificationRaw
            ),
            let reason = OverrideReason(rawValue: snapshot.reasonRaw)
        else {
            return
        }

        modelContext.insert(
            ManualAdjustment(
                id: snapshot.id,
                attendanceDayId: attendanceDayId,
                adjustedClassification: classification,
                reason: reason,
                note: snapshot.note,
                createdAt: snapshot.createdAt,
                updatedAt: snapshot.updatedAt
            )
        )
    }
}

private struct ReviewUndoTransaction {
    let entries: [ReviewUndoEntry]
    let message: String
}

private struct ReviewUndoEntry {
    let day: AttendanceDay
    let wasInserted: Bool
    let attendanceSnapshot: ReviewAttendanceSnapshot?
    let adjustmentSnapshot: ReviewAdjustmentSnapshot?
    let resultingAdjustment: ManualAdjustment?
}

private struct ReviewAttendanceSnapshot {
    let finalClassificationRaw: String
    let manualClassificationRaw: String?
    let complianceTreatmentRaw: String
    let note: String?
    let updatedAt: Date

    init(_ day: AttendanceDay) {
        finalClassificationRaw = day.finalClassificationRaw
        manualClassificationRaw = day.manualClassificationRaw
        complianceTreatmentRaw = day.complianceTreatmentRaw
        note = day.note
        updatedAt = day.updatedAt
    }

    func restore(_ day: AttendanceDay) {
        day.finalClassificationRaw = finalClassificationRaw
        day.manualClassificationRaw = manualClassificationRaw
        day.complianceTreatmentRaw = complianceTreatmentRaw
        day.note = note
        day.updatedAt = updatedAt
    }
}

private struct ReviewAdjustmentSnapshot {
    let id: UUID
    let attendanceDayId: UUID
    let adjustedClassificationRaw: String
    let reasonRaw: String
    let note: String?
    let createdAt: Date
    let updatedAt: Date

    init(_ adjustment: ManualAdjustment) {
        id = adjustment.id
        attendanceDayId = adjustment.attendanceDayId
        adjustedClassificationRaw = adjustment.adjustedClassificationRaw
        reasonRaw = adjustment.reasonRaw
        note = adjustment.note
        createdAt = adjustment.createdAt
        updatedAt = adjustment.updatedAt
    }

    func restore(_ adjustment: ManualAdjustment) {
        adjustment.attendanceDayId = attendanceDayId
        adjustment.adjustedClassificationRaw = adjustedClassificationRaw
        adjustment.reasonRaw = reasonRaw
        adjustment.note = note
        adjustment.createdAt = createdAt
        adjustment.updatedAt = updatedAt
    }
}

#Preview {
    NavigationStack {
        ReviewQueueView(referenceDate: PreviewData.dashboardReferenceDate)
    }
    .modelContainer(PreviewData.modelContainer())
}
