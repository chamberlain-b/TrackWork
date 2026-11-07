import SwiftData
import SwiftUI

struct SettingsView: View {
    @Query(sort: \ComplianceRule.createdAt) private var complianceRules: [ComplianceRule]
    @State private var isEditingPolicy = false

    private var activeRule: ComplianceRule? {
        ComplianceRuleResolver().currentRule(from: complianceRules)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let rule = activeRule {
                        LabeledContent("Office target") {
                            Text(targetSummary(rule))
                                .foregroundStyle(Color.ds.textSecondary)
                        }
                        .accessibilityIdentifier("settings.policyTarget")
                        LabeledContent("Workdays") {
                            Text(SettingsWeekdaySummary.text(
                                for: rule.selectedISOWeekdays, from: SettingsWorkday.all
                            ))
                            .foregroundStyle(Color.ds.textSecondary)
                        }
                        LabeledContent("Holiday region") {
                            Text(JurisdictionCatalog.jurisdictions(
                                for: rule.country ?? .australia
                            ).first { $0.id == rule.jurisdictionId }?.displayName ?? rule.jurisdictionId)
                            .foregroundStyle(Color.ds.textSecondary)
                        }
                    } else {
                        Text("Choose your office target, workdays and holiday region.")
                        Text("Your policy is saved only when you confirm it.")
                            .foregroundStyle(Color.ds.textSecondary)
                    }
                    Button(activeRule == nil ? "Set Up Work Policy" : "Edit Work Policy") {
                        isEditingPolicy = true
                    }
                    .accessibilityIdentifier("settings.editPolicy")
                } header: {
                    Text("Work policy")
                        .foregroundStyle(Color.ds.textSecondary)
                } footer: {
                    if activeRule != nil {
                        Text("Edits apply from the start of this month. Reports use the policy in effect at the end of the selected period.")
                            .foregroundStyle(Color.ds.textSecondary)
                    }
                }
                SettingsTrackingSection()
                SettingsReviewReminderSection()
                SettingsPrivacyDataSection()
            }
            .scrollContentBackground(.hidden)
            .appScreenBackground()
            .navigationTitle("Settings")
            .sheet(isPresented: $isEditingPolicy) {
                WorkPolicyEditorView(rule: activeRule)
            }
        }
    }

    private func targetSummary(_ rule: ComplianceRule) -> String {
        switch rule.requirementType ?? .fixedMonthlyDays {
        case .fixedMonthlyDays:
            "\(rule.fixedRequiredDays ?? 0) days per month"
        case .percentageOfEligibleDays:
            "\(((rule.requiredPercentage ?? 0) * 100).formatted(.number.precision(.fractionLength(0...2))))% of eligible workdays"
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(PreviewData.modelContainer())
        .environment(LocationTrackingService())
}
