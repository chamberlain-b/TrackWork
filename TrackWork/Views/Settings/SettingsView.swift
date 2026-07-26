import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LocationTrackingService.self) private var locationTrackingService
    @Query(sort: \ComplianceRule.createdAt) private var complianceRules: [ComplianceRule]
    @Query(sort: \Place.typeRaw) private var places: [Place]
    @State private var editingRule: ComplianceRule?
    @State private var saveError: String?

    private let ruleResolver = ComplianceRuleResolver()
    private let calendar = Calendar.autoupdatingCurrent

    private let workdays = [
        SettingsWorkday(id: 1, name: "Monday"),
        SettingsWorkday(id: 2, name: "Tuesday"),
        SettingsWorkday(id: 3, name: "Wednesday"),
        SettingsWorkday(id: 4, name: "Thursday"),
        SettingsWorkday(id: 5, name: "Friday"),
        SettingsWorkday(id: 6, name: "Saturday"),
        SettingsWorkday(id: 7, name: "Sunday")
    ]

    private var activeRule: ComplianceRule? {
        editingRule ?? ruleResolver.currentRule(from: complianceRules)
    }

    private var selectedCountry: Country {
        activeRule?.country ?? .australia
    }

    private var availableJurisdictions: [Jurisdiction] {
        JurisdictionCatalog.jurisdictions(for: selectedCountry)
    }

    private var selectedJurisdictionId: String {
        guard let rule = activeRule else {
            return availableJurisdictions.first?.id ?? ""
        }

        if availableJurisdictions.contains(where: { $0.id == rule.jurisdictionId }) {
            return rule.jurisdictionId
        }

        return availableJurisdictions.first?.id ?? ""
    }

    private var selectedRequirementType: RequirementType {
        activeRule?.requirementType ?? .fixedMonthlyDays
    }

    private var countrySelection: Binding<Country> {
        Binding(
            get: { selectedCountry },
            set: updateCountry
        )
    }

    private var jurisdictionSelection: Binding<String> {
        Binding(
            get: { selectedJurisdictionId },
            set: updateJurisdiction
        )
    }

    private var requirementTypeSelection: Binding<RequirementType> {
        Binding(
            get: { selectedRequirementType },
            set: updateRequirementType
        )
    }

    private var fixedRequiredDaysBinding: Binding<Int> {
        Binding(
            get: { activeRule?.fixedRequiredDays ?? 0 },
            set: updateFixedRequiredDays
        )
    }

    private var requiredPercentageInputBinding: Binding<Double> {
        Binding(
            get: { (activeRule?.requiredPercentage ?? 0.5) * 100 },
            set: updateRequiredPercentageInput
        )
    }

    private var prorateFixedTargetBinding: Binding<Bool> {
        Binding(
            get: { activeRule?.prorateFixedTargetForLeave ?? true },
            set: updateProrateFixedTarget
        )
    }

    private var minimumOfficeMinutesBinding: Binding<Int> {
        Binding(
            get: { activeRule?.minimumOfficeMinutes ?? 0 },
            set: updateMinimumOfficeMinutes
        )
    }

    private var workdaySelections: [SettingsWorkdaySelection] {
        workdays.map { workday in
            SettingsWorkdaySelection(
                id: workday.id,
                name: workday.name,
                isSelected: workdaySelection(for: workday.id)
            )
        }
    }

    private var preferredOfficeDaySelections: [SettingsWorkdaySelection] {
        let selectedWorkdays = Set(activeRule?.selectedISOWeekdays ?? [1, 2, 3, 4, 5])
        return workdays
            .filter { selectedWorkdays.contains($0.id) }
            .map { workday in
                SettingsWorkdaySelection(
                    id: workday.id,
                    name: workday.name,
                    isSelected: preferredOfficeDaySelection(for: workday.id)
                )
            }
    }

    var body: some View {
        NavigationStack {
            Form {
                SettingsSetupSummarySection(
                    target: targetSummary,
                    workdays: workdaysSummary,
                    region: regionSummary,
                    automaticAttendance: automaticAttendanceSummary
                )
                SettingsComplianceRuleSection(
                    requirementType: requirementTypeSelection,
                    fixedRequiredDays: fixedRequiredDaysBinding,
                    requiredPercentageInput: requiredPercentageInputBinding,
                    prorateFixedTarget: prorateFixedTargetBinding
                )
                SettingsWorkScheduleSection(
                    minimumOfficeMinutes: minimumOfficeMinutesBinding,
                    workdays: workdaySelections,
                    preferredOfficeDays: preferredOfficeDaySelections
                )
                SettingsRegionSection(
                    availableJurisdictions: availableJurisdictions,
                    country: countrySelection,
                    jurisdictionId: jurisdictionSelection
                )
                SettingsLocationSection()
                SettingsReviewReminderSection()
                SettingsHolidayCoverageSection()
                SettingsPrivacyDataSection()

                if let saveError {
                    Section {
                        Label(saveError, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.ds.critical)
                            .accessibilityIdentifier("settings.saveError")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .appScreenBackground()
            .navigationTitle("Settings")
            .task {
                ensureDefaultRuleExists()
            }
        }
    }

    private func updateCountry(_ country: Country) {
        let rule = ruleForEditing()
        rule.countryCode = country.rawValue

        let jurisdictions = JurisdictionCatalog.jurisdictions(for: country)
        if !jurisdictions.contains(where: { $0.id == rule.jurisdictionId }) {
            rule.jurisdictionId = jurisdictions.first?.id ?? ""
        }

        persist(rule)
    }

    private func updateJurisdiction(_ jurisdictionId: String) {
        guard availableJurisdictions.contains(where: { $0.id == jurisdictionId }) else {
            return
        }

        let rule = ruleForEditing()
        rule.jurisdictionId = jurisdictionId
        persist(rule)
    }

    private func updateRequirementType(_ requirementType: RequirementType) {
        let rule = ruleForEditing()
        rule.requirementTypeRaw = requirementType.rawValue

        if requirementType == .fixedMonthlyDays, rule.fixedRequiredDays == nil {
            rule.fixedRequiredDays = 0
        }

        if requirementType == .percentageOfEligibleDays, rule.requiredPercentage == nil {
            rule.requiredPercentage = 0.5
        }

        persist(rule)
    }

    private func updateFixedRequiredDays(_ fixedRequiredDays: Int) {
        let rule = ruleForEditing()
        rule.fixedRequiredDays = max(0, fixedRequiredDays)
        persist(rule)
    }

    private func updateRequiredPercentageInput(_ requiredPercentageInput: Double) {
        let rule = ruleForEditing()
        let clampedPercentage = min(max(requiredPercentageInput, 0), 100) / 100
        rule.requiredPercentage = clampedPercentage
        persist(rule)
    }

    private func updateProrateFixedTarget(_ prorateFixedTarget: Bool) {
        let rule = ruleForEditing()
        rule.prorateFixedTargetForLeave = prorateFixedTarget
        persist(rule)
    }

    private func updateMinimumOfficeMinutes(_ minimumOfficeMinutes: Int) {
        let rule = ruleForEditing()
        rule.minimumOfficeMinutes = max(0, minimumOfficeMinutes)
        persist(rule)
    }

    private func workdaySelection(for weekday: Int) -> Binding<Bool> {
        Binding(
            get: {
                let selectedWeekdays = activeRule?.selectedISOWeekdays ?? [1, 2, 3, 4, 5]
                return selectedWeekdays.contains(weekday)
            },
            set: { isSelected in
                updateWorkday(weekday, isSelected: isSelected)
            }
        )
    }

    private func updateWorkday(_ weekday: Int, isSelected: Bool) {
        let rule = ruleForEditing()
        var selectedWeekdays = Set(rule.selectedISOWeekdays)

        if isSelected {
            selectedWeekdays.insert(weekday)
        } else {
            guard selectedWeekdays.count > 1 else {
                return
            }
            selectedWeekdays.remove(weekday)
        }

        rule.selectedISOWeekdays = selectedWeekdays.sorted()
        rule.preferredOfficeISOWeekdays = rule.preferredOfficeISOWeekdays.filter {
            selectedWeekdays.contains($0)
        }
        persist(rule)
    }

    private func preferredOfficeDaySelection(for weekday: Int) -> Binding<Bool> {
        Binding(
            get: {
                activeRule?.preferredOfficeISOWeekdays.contains(weekday) ?? false
            },
            set: { isSelected in
                updatePreferredOfficeDay(weekday, isSelected: isSelected)
            }
        )
    }

    private func updatePreferredOfficeDay(_ weekday: Int, isSelected: Bool) {
        let rule = ruleForEditing()
        guard rule.selectedISOWeekdays.contains(weekday) else {
            return
        }

        var preferredWeekdays = Set(rule.preferredOfficeISOWeekdays)
        if isSelected {
            preferredWeekdays.insert(weekday)
        } else {
            preferredWeekdays.remove(weekday)
        }
        rule.preferredOfficeISOWeekdays = preferredWeekdays.sorted()
        persist(rule)
    }

    private func ruleForEditing() -> ComplianceRule {
        if let editingRule {
            return editingRule
        }

        if let existingRule = ruleResolver.ruleEffectiveInMonth(
            containing: .now,
            from: complianceRules,
            calendar: calendar
        ) {
            editingRule = existingRule
            return existingRule
        }

        let monthStart = calendar.dateInterval(of: .month, for: .now)?.start
            ?? calendar.startOfDay(for: .now)
        let baseRule = activeRule ?? ComplianceRule()
        let rule = ruleResolver.copy(baseRule, effectiveFrom: monthStart)
        modelContext.insert(rule)
        editingRule = rule
        return rule
    }

    private func ensureDefaultRuleExists() {
        guard complianceRules.isEmpty else {
            return
        }

        let rule = ComplianceRule()
        modelContext.insert(rule)
        persist(rule)
    }

    private func persist(_ rule: ComplianceRule) {
        rule.updatedAt = .now
        do {
            try modelContext.save()
            saveError = nil
        } catch {
            modelContext.rollback()
            editingRule = nil
            saveError = "Your settings could not be saved. Review the values and try again."
        }
    }

    private var targetSummary: String {
        guard let rule = activeRule else {
            return "Not set"
        }

        switch rule.requirementType ?? .fixedMonthlyDays {
        case .fixedMonthlyDays:
            let days = rule.fixedRequiredDays ?? 0
            return days == 1 ? "1 day/month" : "\(days) days/month"
        case .percentageOfEligibleDays:
            return (rule.requiredPercentage ?? 0)
                .formatted(.percent.precision(.fractionLength(0...1)))
        }
    }

    private var workdaysSummary: String {
        SettingsWeekdaySummary.text(
            for: activeRule?.selectedISOWeekdays ?? [1, 2, 3, 4, 5],
            from: workdays
        )
    }

    private var regionSummary: String {
        JurisdictionCatalog.jurisdictions(for: selectedCountry)
            .first { $0.id == selectedJurisdictionId }?
            .displayName
            ?? "Not set"
    }

    private var automaticAttendanceSummary: String {
        if locationTrackingService.isAutomaticTrackingEnabled {
            return "On"
        }
        return places.contains(where: \.isActive) ? "Off" : "Not set up"
    }
}

#Preview {
    SettingsView()
        .modelContainer(PreviewData.modelContainer())
        .environment(LocationTrackingService())
}
