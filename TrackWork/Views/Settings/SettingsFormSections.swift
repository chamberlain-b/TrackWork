import SwiftUI

struct SettingsLocationSection: View {
    var body: some View {
        Section {
            NavigationLink {
                LocationSetupView()
            } label: {
                Label("Location Setup", systemImage: "location.circle")
            }

            #if DEBUG
            NavigationLink {
                RecentLocationEventsView()
            } label: {
                Label("Recent Location Events", systemImage: "list.bullet.rectangle")
            }
            #endif
        } header: {
            Text("Location")
        } footer: {
            Text(
                "Save home and office places by entering coordinates or choosing a point on the map. "
                    + "Automatic detection is off in this MVP; manual attendance remains available."
            )
        }
    }
}

struct SettingsRegionSection: View {
    let availableJurisdictions: [Jurisdiction]
    @Binding var country: Country
    @Binding var jurisdictionId: String

    var body: some View {
        Section {
            Picker("Country", selection: $country) {
                ForEach(Country.allCases) { country in
                    Text(country.displayName)
                        .tag(country)
                }
            }
            .accessibilityIdentifier("settings.country")

            Picker("Jurisdiction", selection: $jurisdictionId) {
                ForEach(availableJurisdictions) { jurisdiction in
                    Text(jurisdiction.displayName)
                        .tag(jurisdiction.id)
                }
            }
            .accessibilityIdentifier("settings.jurisdiction")
        } header: {
            Text("Region")
        } footer: {
            Text("Public holidays and monthly compliance use the selected country and jurisdiction.")
        }
    }
}

struct SettingsComplianceRuleSection: View {
    @Binding var requirementType: RequirementType
    @Binding var fixedRequiredDays: Int
    @Binding var requiredPercentageInput: Double
    @Binding var prorateFixedTarget: Bool

    var body: some View {
        Section {
            Picker("Requirement", selection: $requirementType) {
                ForEach(RequirementType.allCases) { requirementType in
                    Text(requirementType.displayName)
                        .tag(requirementType)
                }
            }
            .accessibilityIdentifier("settings.requirementType")

            if requirementType == .fixedMonthlyDays {
                LabeledContent("Required office days") {
                    TextField("Days", value: $fixedRequiredDays, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .accessibilityIdentifier("settings.fixedRequiredDays")
                }

                Toggle("Prorate fixed target for leave", isOn: $prorateFixedTarget)
                    .accessibilityIdentifier("settings.prorateFixedTarget")
            } else {
                LabeledContent("Required percentage") {
                    TextField(
                        "Percent",
                        value: $requiredPercentageInput,
                        format: .number.precision(.fractionLength(0...2))
                    )
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                }
            }
        } header: {
            Text("Compliance Rule")
        } footer: {
            if requirementType == .fixedMonthlyDays {
                Text("Fixed days must be 0 or greater. Leave prorating is on by default.")
            } else {
                Text("Enter a percentage from 0 to 100. The stored rule uses the equivalent 0 to 1 value.")
            }
        }
    }
}

struct SettingsOfficeDaySection: View {
    @Binding var minimumOfficeMinutes: Int

    var body: some View {
        Section {
            LabeledContent("Minimum office minutes") {
                TextField("Minutes", value: $minimumOfficeMinutes, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
            }
        } header: {
            Text("Office Day")
        } footer: {
            Text("Minimum office minutes must be 0 or greater.")
        }
    }
}

struct SettingsWorkdaysSection: View {
    let workdays: [SettingsWorkdaySelection]

    var body: some View {
        Section {
            ForEach(workdays) { workday in
                Toggle(workday.name, isOn: workday.isSelected)
            }
        } header: {
            Text("Selected Workdays")
        } footer: {
            Text("At least one workday must remain selected. Monday to Friday is the default.")
        }
    }
}

struct SettingsPrivacyDataSection: View {
    var body: some View {
        Section {
            NavigationLink {
                PrivacyDataView()
            } label: {
                Label("Privacy & Data", systemImage: "hand.raised")
            }
            .accessibilityIdentifier("settings.privacyData")
        } header: {
            Text("Privacy")
        } footer: {
            Text("Review on-device storage, report privacy, and permanent data deletion controls.")
        }
    }
}

struct SettingsWorkday: Identifiable {
    let id: Int
    let name: String
}

struct SettingsWorkdaySelection: Identifiable {
    let id: Int
    let name: String
    let isSelected: Binding<Bool>
}
