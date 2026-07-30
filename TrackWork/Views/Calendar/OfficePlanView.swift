import SwiftData
import SwiftUI

struct OfficePlanView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \AttendanceDay.date) var attendanceDays: [AttendanceDay]
    @Query(sort: \LeaveRecord.date) var leaveRecords: [LeaveRecord]
    @Query(sort: \PublicHoliday.date) var publicHolidays: [PublicHoliday]
    @Query(sort: \CustomExcludedDay.date) var customExcludedDays: [CustomExcludedDay]
    @Query(sort: \PlannedOfficeDay.date) var plannedOfficeDays: [PlannedOfficeDay]
    @Query(sort: \ComplianceRule.createdAt) var complianceRules: [ComplianceRule]

    @State private var displayedMonth: Date
    @State private var collapsedWeekStarts: Set<Date> = []
    @State private var isConfirmingReplan = false
    @State private var isConfirmingUnavailableRemoval = false
    @State private var saveError: String?

    let referenceDate: Date
    let calendar = Calendar.workTrackCalendar
    let candidateDateCalculator = OfficePlanCandidateDateCalculator()
    let evaluator = CompliancePeriodEvaluator()
    let reconciliationService = OfficePlanReconciliationService()
    let ruleResolver = ComplianceRuleResolver()
    let suggestionService = OfficePlanSuggestionService()

    init(displayedMonth: Date? = nil, referenceDate: Date = .now) {
        self.referenceDate = referenceDate
        _displayedMonth = State(initialValue: displayedMonth ?? referenceDate)
    }

    var displayedMonthValue: Date {
        displayedMonth
    }

    var usesAccessibilityAgenda: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    func isWeekCollapsed(_ week: OfficePlanWeek) -> Bool {
        collapsedWeekStarts.contains(week.start)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text("Plan Office Days")
                    .font(AppTypography.title)
                    .foregroundStyle(Color.ds.textSecondary)

                referenceDateMenu
                planSurface

                if let saveError {
                    Label(saveError, systemImage: "exclamationmark.triangle.fill")
                        .font(AppTypography.callout)
                        .foregroundStyle(Color.ds.critical)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("officePlan.saveError")
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.bottom, AppSpacing.xl)
        }
        .appScreenBackground()
        .navigationTitle("Adaptive Month Plan")
        .navigationBarTitleDisplayMode(.large)
        .accessibilityIdentifier("officePlan.screen")
        .confirmationDialog(
            "Re-plan \(monthTitle)?",
            isPresented: $isConfirmingReplan,
            titleVisibility: .visible
        ) {
            Button("Replace plan", role: .destructive) {
                replanMonth()
            }
            .accessibilityIdentifier("officePlan.confirmReplan")

            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "This replaces planned office days in \(monthTitle). "
                    + "Notes on dates that change are removed. Attendance is unchanged."
            )
        }
        .confirmationDialog(
            "Remove unavailable plans?",
            isPresented: $isConfirmingUnavailableRemoval,
            titleVisibility: .visible
        ) {
            Button(removeUnavailablePlansTitle, role: .destructive) {
                removeUnavailablePlans()
            }
            .accessibilityIdentifier("officePlan.confirmUnavailableRemoval")

            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "This removes unavailable reminders and any notes attached to them. "
                    + "Attendance is unchanged."
            )
        }
    }
}

extension OfficePlanView {
    func toggleWeek(_ week: OfficePlanWeek) {
        if collapsedWeekStarts.contains(week.start) {
            collapsedWeekStarts.remove(week.start)
        } else {
            collapsedWeekStarts.insert(week.start)
        }
    }

    func moveMonth(by offset: Int) {
        guard let month = calendar.date(byAdding: .month, value: offset, to: range.start) else {
            return
        }
        updateDisplayedMonth(month)
    }

    func showReferenceMonth() {
        updateDisplayedMonth(referenceDate)
    }

    func updateDisplayedMonth(_ month: Date) {
        collapsedWeekStarts.removeAll()
        if reduceMotion {
            displayedMonth = month
        } else {
            withAnimation(AppMotion.smooth) {
                displayedMonth = month
            }
        }
    }

    func requestReplan() {
        isConfirmingReplan = true
    }

    func updatePlan(for date: Date, isSelected: Bool) {
        let normalizedDate = calendar.startOfDay(for: date)
        guard candidateDateSet.contains(normalizedDate) else {
            return
        }

        if isSelected {
            guard !selectedDates.contains(normalizedDate),
                  !plannedOfficeDays.contains(where: {
                      calendar.isDate($0.date, inSameDayAs: normalizedDate)
                  }) else {
                return
            }
            modelContext.insert(PlannedOfficeDay(date: normalizedDate))
        } else {
            plannedOfficeDays
                .filter { calendar.isDate($0.date, inSameDayAs: normalizedDate) }
                .forEach(modelContext.delete)
        }
        persist()
    }

    func suggestPlan() {
        let datesToAdd = suggestionService.balancedSuggestedDates(
            from: candidateDates,
            excluding: selectedDates,
            count: additionalPlansNeeded,
            preferredISOWeekdays: preferredISOWeekdays,
            calendar: calendar
        )
        datesToAdd
            .filter { date in
                !plannedOfficeDays.contains {
                    calendar.isDate($0.date, inSameDayAs: date)
                }
            }
            .forEach { modelContext.insert(PlannedOfficeDay(date: $0)) }
        persist()
    }

    func removeUnavailablePlans() {
        invalidSelectedPlans.forEach(modelContext.delete)
        persist()
    }

    func requestUnavailablePlanRemoval() {
        guard unavailableRemovalNeedsConfirmation else {
            removeUnavailablePlans()
            return
        }
        isConfirmingUnavailableRemoval = true
    }

    func replanMonth() {
        let refreshedDates = suggestionService.balancedSuggestedDates(
            from: candidateDates,
            excluding: [],
            count: remainingOfficeDays,
            preferredISOWeekdays: preferredISOWeekdays,
            calendar: calendar
        )
        reconcilePlan(with: refreshedDates)
        persist()
    }

    func reconcilePlan(with refreshedDates: [Date]) {
        let reconciliation = reconciliationService.changes(
            existingPlans: plannedOfficeDays,
            desiredDates: refreshedDates,
            range: range,
            calendar: calendar
        )
        reconciliation.plansToDelete.forEach(modelContext.delete)
        reconciliation.datesToInsert.forEach {
            modelContext.insert(PlannedOfficeDay(date: $0))
        }
    }

    func persist() {
        do {
            try modelContext.save()
            saveError = nil
        } catch {
            modelContext.rollback()
            saveError = "Your office plan could not be saved. Try again."
        }
    }
}

#Preview {
    NavigationStack {
        OfficePlanView(referenceDate: PreviewData.dashboardReferenceDate)
    }
    .modelContainer(PreviewData.modelContainer())
}
