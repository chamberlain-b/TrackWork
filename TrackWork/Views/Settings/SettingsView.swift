import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ComplianceRule.createdAt) private var complianceRules: [ComplianceRule]

    private let workdays = [
        Workday(id: 1, name: "Monday"),
        Workday(id: 2, name: "Tuesday"),
        Workday(id: 3, name: "Wednesday"),
        Workday(id: 4, name: "Thursday"),
        Workday(id: 5, name: "Friday"),
        Workday(id: 6, name: "Saturday"),
        Workday(id: 7, name: "Sunday")
    ]

    private var activeRule: ComplianceRule? {
        complianceRules.first
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

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        LocationSetupView()
                    } label: {
                        Label("Location Setup", systemImage: "location.circle")
                    }
                } header: {
                    Text("Location")
                } footer: {
                    Text("Save home and office coordinates for later attendance detection. This does not request location permission or start tracking.")
                }

                Section {
                    Picker("Country", selection: countrySelection) {
                        ForEach(Country.allCases) { country in
                            Text(country.displayName)
                                .tag(country)
                        }
                    }

                    Picker("Jurisdiction", selection: jurisdictionSelection) {
                        ForEach(availableJurisdictions) { jurisdiction in
                            Text(jurisdiction.displayName)
                                .tag(jurisdiction.id)
                        }
                    }
                } header: {
                    Text("Region")
                } footer: {
                    Text("Public holidays and monthly compliance use the selected country and jurisdiction.")
                }

                Section {
                    Picker("Requirement type", selection: requirementTypeSelection) {
                        ForEach(RequirementType.allCases) { requirementType in
                            Text(requirementType.displayName)
                                .tag(requirementType)
                        }
                    }
                    .pickerStyle(.segmented)

                    if selectedRequirementType == .fixedMonthlyDays {
                        TextField("Fixed required days", value: fixedRequiredDaysBinding, format: .number)
                            .keyboardType(.numberPad)

                        Toggle("Prorate fixed target for leave", isOn: prorateFixedTargetBinding)
                    } else {
                        TextField(
                            "Required percentage",
                            value: requiredPercentageInputBinding,
                            format: .number.precision(.fractionLength(0...2))
                        )
                        .keyboardType(.decimalPad)
                    }
                } header: {
                    Text("Compliance Rule")
                } footer: {
                    if selectedRequirementType == .fixedMonthlyDays {
                        Text("Fixed days must be 0 or greater. Leave prorating is on by default.")
                    } else {
                        Text("Enter a percentage from 0 to 100. The stored rule uses the equivalent 0 to 1 value.")
                    }
                }

                Section {
                    TextField("Minimum office minutes", value: minimumOfficeMinutesBinding, format: .number)
                        .keyboardType(.numberPad)
                } header: {
                    Text("Office Day")
                } footer: {
                    Text("Minimum office minutes must be 0 or greater.")
                }

                Section {
                    ForEach(workdays) { workday in
                        Toggle(workday.name, isOn: workdaySelection(for: workday.id))
                    }
                } header: {
                    Text("Selected Workdays")
                } footer: {
                    Text("At least one workday must remain selected. Monday to Friday is the default.")
                }
            }
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
        persist(rule)
    }

    private func ruleForEditing() -> ComplianceRule {
        if let activeRule {
            return activeRule
        }

        let rule = ComplianceRule()
        modelContext.insert(rule)
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
        try? modelContext.save()
    }
}

private struct Workday: Identifiable {
    let id: Int
    let name: String
}

#Preview {
    SettingsView()
        .modelContainer(PreviewData.modelContainer())
}
