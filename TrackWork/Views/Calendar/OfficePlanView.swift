import SwiftData
import SwiftUI

struct OfficePlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AttendanceDay.date) private var attendanceDays: [AttendanceDay]
    @Query(sort: \LeaveRecord.date) private var leaveRecords: [LeaveRecord]
    @Query(sort: \PublicHoliday.date) private var publicHolidays: [PublicHoliday]
    @Query(sort: \CustomExcludedDay.date) private var customExcludedDays: [CustomExcludedDay]
    @Query(sort: \PlannedOfficeDay.date) private var plannedOfficeDays: [PlannedOfficeDay]
    @Query(sort: \ComplianceRule.createdAt) private var complianceRules: [ComplianceRule]

    @State private var saveError: String?

    private let displayedMonth: Date
    private let referenceDate: Date
    private let calendar = Calendar.workTrackCalendar
    private let evaluator = CompliancePeriodEvaluator()
    private let ruleResolver = ComplianceRuleResolver()

    init(displayedMonth: Date? = nil, referenceDate: Date = .now) {
        self.displayedMonth = displayedMonth ?? referenceDate
        self.referenceDate = referenceDate
    }

    private var range: ComplianceDateRange {
        ComplianceDateRange(
            start: calendar.complianceMonthStart(for: displayedMonth),
            end: calendar.complianceMonthEnd(for: displayedMonth),
            calendar: calendar
        )
    }

    private var activeRule: ComplianceRule {
        ruleResolver.rule(for: range.end, from: complianceRules) ?? ComplianceRule()
    }

    private var summary: ComplianceSummary {
        evaluator.evaluate(
            CompliancePeriodEvaluator.Input(
                range: range,
                calendar: calendar,
                rule: activeRule,
                attendanceDays: attendanceDays,
                leaveRecords: leaveRecords,
                publicHolidays: publicHolidays,
                customExcludedDays: customExcludedDays,
                evaluationDate: calendar.startOfDay(for: referenceDate)
            )
        )
    }

    private var candidateDates: [Date] {
        let holidayDates = Set(
            publicHolidays.compactMap { holiday -> Date? in
                guard holiday.jurisdictionId == activeRule.jurisdictionId,
                      range.contains(holiday.date, calendar: calendar) else {
                    return nil
                }
                return calendar.startOfDay(for: holiday.date)
            }
        )
        let eligibleBeforeLeave = BusinessDayCalculator().eligibleDates(
            from: range.start,
            through: range.end,
            calendar: calendar,
            selectedISOWeekdays: Set(activeRule.selectedISOWeekdays),
            publicHolidays: holidayDates
        )
        let leaveDates = Set(
            leaveRecords.compactMap { record -> Date? in
                guard record.duration == .fullDay else { return nil }
                let date = calendar.startOfDay(for: record.date)
                return eligibleBeforeLeave.contains(date) ? date : nil
            }
        )
        let exclusionDates = Set(
            customExcludedDays.map { calendar.startOfDay(for: $0.date) }
        )
        let completedDates = Set(
            attendanceDays.compactMap { day -> Date? in
                let date = calendar.startOfDay(for: day.date)
                guard range.contains(date, calendar: calendar) else { return nil }
                switch day.finalClassification {
                case .office:
                    return date
                case .mixed where day.officeMinutes >= activeRule.minimumOfficeMinutes:
                    return date
                default:
                    return nil
                }
            }
        )
        let today = calendar.startOfDay(for: referenceDate)

        return eligibleBeforeLeave
            .subtracting(leaveDates)
            .subtracting(exclusionDates)
            .subtracting(completedDates)
            .filter { $0 >= today }
            .sorted()
    }

    private var selectedDates: Set<Date> {
        Set(
            plannedOfficeDays.compactMap { plan in
                let date = calendar.startOfDay(for: plan.date)
                return range.contains(date, calendar: calendar) ? date : nil
            }
        )
    }

    private var remainingOfficeDays: Int {
        summary.officeDaysNeeded
    }

    private var additionalPlansNeeded: Int {
        max(0, remainingOfficeDays - plannedCandidateDays)
    }

    private var plannedCandidateDays: Int {
        selectedDates.intersection(Set(candidateDates)).count
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: AppSpacing.sm) {
                            remainingDaysLabel
                            Spacer(minLength: AppSpacing.xs)
                            planStatus
                        }

                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            remainingDaysLabel
                            planStatus
                        }
                    }

                    Text("Plans are reminders. Only confirmed attendance counts.")
                        .font(AppTypography.caption)
                        .foregroundStyle(Color.ds.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if summary.reviewRequiredDays > 0 {
                        Label(
                            reviewRequiredMessage,
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(AppTypography.caption)
                        .foregroundStyle(Color.ds.warning)
                    } else if remainingOfficeDays > candidateDates.count {
                        Label(
                            unreachableTargetMessage,
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(AppTypography.caption)
                        .foregroundStyle(Color.ds.critical)
                    }
                }
                .padding(.vertical, AppSpacing.xxs)
            }

            Section {
                Button("Suggest Days", systemImage: "wand.and.stars") {
                    suggestPlan()
                }
                .disabled(additionalPlansNeeded == 0 || candidateDates.isEmpty)
                .accessibilityIdentifier("officePlan.suggest")

                Button("Clear Plan", systemImage: "xmark.circle", role: .destructive) {
                    clearPlan()
                }
                .disabled(selectedDates.isEmpty)
            }

            Section("Available days") {
                if candidateDates.isEmpty {
                    ContentUnavailableView(
                        "No eligible days available",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("No workdays remain after leave, holidays, exclusions and attendance.")
                    )
                } else {
                    ForEach(candidateDates, id: \.self) { date in
                        Toggle(isOn: selectionBinding(for: date)) {
                            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                                    .font(AppTypography.headline)
                                Text(selectedDates.contains(date) ? "Planned" : "Available")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(Color.ds.textSecondary)
                            }
                        }
                        .tint(Color.ds.accentPrimary)
                        .accessibilityIdentifier("officePlan.\(calendar.calendarDayAccessibilityIdentifier(for: date))")
                    }
                }
            }

            if let saveError {
                Section {
                    Label(saveError, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.ds.critical)
                }
            }
        }
        .navigationTitle("Plan Office Days")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func selectionBinding(for date: Date) -> Binding<Bool> {
        Binding(
            get: { selectedDates.contains(date) },
            set: { isSelected in updatePlan(for: date, isSelected: isSelected) }
        )
    }

    private func updatePlan(for date: Date, isSelected: Bool) {
        let normalizedDate = calendar.startOfDay(for: date)
        if isSelected {
            guard !selectedDates.contains(normalizedDate) else { return }
            modelContext.insert(PlannedOfficeDay(date: normalizedDate))
        } else {
            plannedOfficeDays
                .filter { calendar.isDate($0.date, inSameDayAs: normalizedDate) }
                .forEach(modelContext.delete)
        }
        persist()
    }

    private func suggestPlan() {
        let datesToAdd = candidateDates
            .filter { !selectedDates.contains($0) }
            .prefix(additionalPlansNeeded)
        datesToAdd.forEach { modelContext.insert(PlannedOfficeDay(date: $0)) }
        persist()
    }

    private func clearPlan() {
        plannedOfficeDays
            .filter { range.contains($0.date, calendar: calendar) }
            .forEach(modelContext.delete)
        persist()
    }

    private func persist() {
        do {
            try modelContext.save()
            saveError = nil
        } catch {
            modelContext.rollback()
            saveError = "Your office plan could not be saved. Try again."
        }
    }
}

private extension OfficePlanView {
    var remainingDaysLabel: some View {
        Label(
            remainingDaysText,
            systemImage: "target"
        )
        .font(AppTypography.headline)
    }

    var remainingDaysText: String {
        if summary.reviewRequiredDays > 0 {
            return remainingOfficeDays == 1
                ? "1 office day currently needed"
                : "\(remainingOfficeDays) office days currently needed"
        }

        return remainingOfficeDays == 1
            ? "1 office day left"
            : "\(remainingOfficeDays) office days left"
    }

    var planStatus: some View {
        DSStatusPill(
            text: planStatusText,
            systemImage: additionalPlansNeeded == 0 ? "checkmark" : "calendar.badge.clock",
            style: additionalPlansNeeded == 0 ? .success : .info
        )
    }

    var planStatusText: String {
        if additionalPlansNeeded == 0 {
            return "Plan ready"
        }
        if plannedCandidateDays == 0 {
            return "None planned"
        }
        return "\(plannedCandidateDays) planned"
    }

    var unreachableTargetMessage: String {
        let availableDays = candidateDates.count
        let availableLabel = availableDays == 1
            ? "1 eligible workday remains"
            : "\(availableDays) eligible workdays remain"
        let targetLabel = summary.requiredOfficeDays == 1
            ? "the 1-day target"
            : "the \(summary.requiredOfficeDays)-day target"
        return "\(availableLabel), so \(targetLabel) is not reachable."
    }

    var reviewRequiredMessage: String {
        let count = summary.reviewRequiredDays
        let dayLabel = count == 1 ? "1 day still needs" : "\(count) days still need"
        return "\(dayLabel) review, so this plan may change."
    }
}

#Preview {
    NavigationStack {
        OfficePlanView(referenceDate: PreviewData.dashboardReferenceDate)
    }
    .modelContainer(PreviewData.modelContainer())
}
