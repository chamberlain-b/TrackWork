import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ComplianceRule.createdAt) private var complianceRules: [ComplianceRule]

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

    var body: some View {
        NavigationStack {
            Form {
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

#Preview {
    SettingsView()
        .modelContainer(PreviewData.modelContainer())
}
