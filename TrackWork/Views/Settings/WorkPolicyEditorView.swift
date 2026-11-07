import SwiftData
import SwiftUI

struct WorkPolicyEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var draft: WorkPolicyDraft
    @State private var fixedDaysText: String
    @State private var percentageText: String
    @State private var minimumMinutesText: String
    @State private var validationError: String?
    @State private var validationAttempt = 0
    @State private var showsSaveError = false
    @State private var hasSaveFailure = false
    @State private var hasInjectedSaveFailure = false

    private let isInitialSetup: Bool
    @State private var effectiveDate: Date

    init(rule: ComplianceRule?) {
        let draft = WorkPolicyDraft(rule: rule)
        _draft = State(initialValue: draft)
        _fixedDaysText = State(initialValue: String(draft.fixedRequiredDays))
        _percentageText = State(initialValue: (draft.requiredPercentage * 100).formatted(.number.precision(.fractionLength(0...2))))
        _minimumMinutesText = State(initialValue: String(draft.minimumOfficeMinutes))
        isInitialSetup = rule == nil
        _effectiveDate = State(initialValue: Calendar.autoupdatingCurrent.dateInterval(of: .month, for: .now)?.start ?? .now)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                Form {
                    Section {
                        Text(isInitialSetup
                             ? "Review the suggested values below, then confirm your policy."
                             : "Changes apply from \(effectiveDate.formatted(date: .abbreviated, time: .omitted)). This month’s target and progress will be recalculated.")
                            .accessibilityIdentifier("settings.policyEffectiveDate")
                        Text(isInitialSetup
                             ? "This first policy applies to all recorded dates. You can use TrackWork without location access."
                             : "Your previous policies, attendance records and manual corrections are kept. Reports use the policy in effect on the last day of the selected period.")
                            .foregroundStyle(Color.ds.textSecondary)
                    }

                    if let validationError {
                        Section {
                            Label(validationError, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.ds.critical)
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(validationError)
                                .accessibilityIdentifier("settings.policyValidation")
                                .id("policyValidation")
                        }
                    }

                    if hasSaveFailure {
                        Section {
                            Label("Your changes are still in this draft. Your saved policy has not changed.", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.ds.critical)
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("Your changes are still in this draft. Your saved policy has not changed.")
                                .accessibilityIdentifier("settings.policySaveError")
                                .id("policySaveError")
                            Button("Retry Save", action: save)
                        }
                    }

                    SettingsWorkPolicySection(
                        availableJurisdictions: JurisdictionCatalog.jurisdictions(for: draft.country),
                        workdays: daySelections(preferred: false),
                        preferredOfficeDays: daySelections(preferred: true),
                        country: Binding(get: { draft.country }, set: updateCountry),
                        jurisdictionId: $draft.jurisdictionId,
                        requirementType: $draft.requirementType,
                        fixedRequiredDays: $fixedDaysText,
                        requiredPercentageInput: $percentageText,
                        prorateFixedTarget: $draft.prorateFixedTargetForLeave
                    )

                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Minimum office time")
                            HStack {
                                TextField("Minutes", text: $minimumMinutesText)
                                    .foregroundStyle(Color.ds.textPrimary)
                                    .keyboardType(.numberPad)
                                    .accessibilityLabel("Minimum office time in minutes")
                                    .accessibilityIdentifier("settings.minimumOfficeMinutes")
                                Text("minutes")
                                    .foregroundStyle(Color.ds.textSecondary)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                        }
                    } header: {
                        Text("Automatic attendance")
                            .foregroundStyle(Color.ds.textSecondary)
                    } footer: {
                        Text("Used to classify detected office time. Manual office entries do not need location access. Automatic Attendance stays optional.")
                            .foregroundStyle(Color.ds.textSecondary)
                    }
                }
                .onChange(of: validationAttempt) { _, _ in
                    if validationError != nil { scrollProxy.scrollTo("policyValidation", anchor: .top) }
                }
                .onChange(of: showsSaveError) { _, isPresented in
                    if !isPresented && hasSaveFailure { scrollProxy.scrollTo("policySaveError", anchor: .top) }
                }
                .scrollContentBackground(.hidden)
                .appScreenBackground()
                .navigationTitle(isInitialSetup ? "Set Up Work Policy" : "Work Policy")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .accessibilityIdentifier("settings.cancelPolicy")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(isInitialSetup ? "Confirm" : "Save", action: save)
                            .accessibilityLabel(isInitialSetup ? "Confirm Policy" : "Save Policy")
                            .accessibilityIdentifier("settings.savePolicy")
                    }
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                    }
                }
                .alert("Policy couldn’t be saved", isPresented: $showsSaveError) {
                    Button("Retry", action: save)
                        .accessibilityIdentifier("settings.retryPolicySave")
                    Button("Keep Editing", role: .cancel) { }
                } message: {
                    Text("Your changes are still in this draft. Try saving again. Your saved policy has not changed.")
                }
            }
        }
        // Explicit Cancel discards the draft; an accidental swipe cannot discard entered values.
        .interactiveDismissDisabled()
    }

    private func updateCountry(_ country: Country) {
        draft.country = country
        let available = JurisdictionCatalog.jurisdictions(for: country)
        if !available.contains(where: { $0.id == draft.jurisdictionId }) {
            draft.jurisdictionId = available.first?.id ?? ""
        }
    }

    private func daySelections(preferred: Bool) -> [SettingsWorkdaySelection] {
        SettingsWorkday.all.filter { !preferred || draft.selectedISOWeekdays.contains($0.id) }.map { day in
            SettingsWorkdaySelection(id: day.id, name: day.name, isSelected: Binding(
                get: {
                    (preferred ? draft.preferredOfficeISOWeekdays : draft.selectedISOWeekdays).contains(day.id)
                },
                set: { selected in
                    if preferred {
                        var days = Set(draft.preferredOfficeISOWeekdays)
                        if selected { days.insert(day.id) } else { days.remove(day.id) }
                        draft.preferredOfficeISOWeekdays = days.sorted()
                    } else {
                        var days = Set(draft.selectedISOWeekdays)
                        if selected { days.insert(day.id) } else if days.count > 1 { days.remove(day.id) }
                        draft.selectedISOWeekdays = days.sorted()
                        draft.preferredOfficeISOWeekdays.removeAll { !days.contains($0) }
                    }
                }
            ))
        }
    }

    private func save() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        validationAttempt += 1
        let now = Date.now
        let monthStart = Calendar.autoupdatingCurrent.dateInterval(of: .month, for: now)?.start ?? now
        if !isInitialSetup && !Calendar.autoupdatingCurrent.isDate(effectiveDate, inSameDayAs: monthStart) {
            effectiveDate = monthStart
            validationError = "A new month has started. Review the updated effective date, then save again."
            return
        }
        var validatedDraft = draft
        if draft.requirementType == .fixedMonthlyDays {
            guard let days = Int(fixedDaysText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                validationError = "Enter an office target in whole days."
                return
            }
            validatedDraft.fixedRequiredDays = days
        } else {
            guard let percentage = try? Double(percentageText, format: .number.locale(.current)) else {
                validationError = "Enter an office target between 0% and 100%."
                return
            }
            validatedDraft.requiredPercentage = percentage / 100
        }
        guard let minutes = Int(minimumMinutesText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            validationError = "Enter a minimum office time in whole minutes."
            return
        }
        validatedDraft.minimumOfficeMinutes = minutes
        if let message = validatedDraft.validationMessage {
            validationError = message
            return
        }
        validationError = nil
        draft = validatedDraft
        do {
            #if DEBUG
            if AppLaunchConfiguration.isUITesting,
               ProcessInfo.processInfo.environment["TRACKWORK_UI_POLICY_SAVE_FAILURE"] == "once",
               !hasInjectedSaveFailure {
                hasInjectedSaveFailure = true
                throw CocoaError(.fileWriteUnknown)
            }
            #endif
            try WorkPolicyEditor(container: modelContext.container).save(draft: validatedDraft, now: now)
            dismiss()
        } catch {
            hasSaveFailure = true
            showsSaveError = true
        }
    }
}
