import SwiftUI
import UIKit

struct SettingsTrackingSection: View {
    var body: some View {
        Section {
            NavigationLink {
                AutomaticLocationTrackingView()
            } label: {
                Label("Automatic Attendance", systemImage: "location.viewfinder")
            }
            .accessibilityIdentifier("settings.automaticAttendance")

            NavigationLink {
                LocationSetupView()
            } label: {
                Label("Locations", systemImage: "location.circle")
            }
            .accessibilityIdentifier("settings.locations")

        } header: {
            Text("Automatic attendance · Optional")
                .foregroundStyle(Color.ds.textSecondary)
        } footer: {
            Text("You can record attendance manually in Calendar. Location access is needed only for automatic attendance and location checks.")
                .foregroundStyle(Color.ds.textSecondary)
        }
    }
}

struct SettingsWorkPolicySection: View {
    let availableJurisdictions: [Jurisdiction]
    let workdays: [SettingsWorkdaySelection]
    let preferredOfficeDays: [SettingsWorkdaySelection]

    @Binding var country: Country
    @Binding var jurisdictionId: String
    @Binding var requirementType: RequirementType
    @Binding var fixedRequiredDays: String
    @Binding var requiredPercentageInput: String
    @Binding var prorateFixedTarget: Bool

    var body: some View {
        Section {
            Picker("Target type", selection: $requirementType) {
                ForEach(RequirementType.allCases) { requirementType in
                    Text(requirementType.displayName)
                        .tag(requirementType)
                }
            }
            .accessibilityIdentifier("settings.requirementType")

            targetValue

            if requirementType == .fixedMonthlyDays {
                Toggle("Reduce target for full-day leave", isOn: $prorateFixedTarget)
                    .accessibilityIdentifier("settings.prorateFixedTarget")
            }

            NavigationLink {
                SettingsWorkdaysView(workdays: workdays)
            } label: {
                LabeledContent("Workdays") {
                    Text(selectedWorkdaysSummary)
                        .foregroundStyle(Color.ds.textSecondary)
                }
            }
            .accessibilityIdentifier("settings.workdays")

            NavigationLink {
                SettingsPreferredOfficeDaysView(workdays: preferredOfficeDays)
            } label: {
                LabeledContent("Preferred office days") {
                    Text(preferredOfficeDaysSummary)
                        .foregroundStyle(Color.ds.textSecondary)
                }
            }
            .accessibilityIdentifier("settings.preferredOfficeDays")

            Picker("Country", selection: $country) {
                ForEach(Country.allCases) { country in
                    Text(country.displayName)
                        .tag(country)
                }
            }
            .accessibilityIdentifier("settings.country")

            Picker("State or region", selection: $jurisdictionId) {
                ForEach(availableJurisdictions) { jurisdiction in
                    Text(jurisdiction.displayName)
                        .tag(jurisdiction.id)
                }
            }
            .accessibilityIdentifier("settings.jurisdiction")

            Label(HolidayCoverage.statusText, systemImage: "checkmark.seal.fill")
                .foregroundStyle(Color.ds.success)
        } header: {
            Text("Work policy")
                .foregroundStyle(Color.ds.textSecondary)
        } footer: {
            Text(workPolicyFooter)
                .foregroundStyle(Color.ds.textSecondary)
        }
    }

    @ViewBuilder
    private var targetValue: some View {
        if requirementType == .fixedMonthlyDays {
            LabeledContent("Days per month") {
                TextField("Days", text: $fixedRequiredDays)
                    .foregroundStyle(Color.ds.textPrimary)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(minWidth: 80, idealWidth: 100, maxWidth: 160)
                    .accessibilityIdentifier("settings.fixedRequiredDays")
            }
        } else {
            LabeledContent("Required office rate") {
                HStack(spacing: AppSpacing.xxs) {
                    TextField(
                        "Percent",
                        text: $requiredPercentageInput
                    )
                    .accessibilityIdentifier("settings.requiredPercentage")
                    .foregroundStyle(Color.ds.textPrimary)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(minWidth: 80, idealWidth: 100, maxWidth: 160)

                    Text("%")
                        .foregroundStyle(Color.ds.textSecondary)
                }
            }
        }
    }

    private var selectedWorkdaysSummary: String {
        let selectedIds = workdays
            .filter { $0.isSelected.wrappedValue }
            .map(\.id)

        return SettingsWeekdaySummary.text(
            for: selectedIds,
            from: workdays.map { SettingsWorkday(id: $0.id, name: $0.name) }
        )
    }

    private var preferredOfficeDaysSummary: String {
        let selected = preferredOfficeDays.filter { $0.isSelected.wrappedValue }
        guard !selected.isEmpty else {
            return "No preference"
        }
        if selected.count == preferredOfficeDays.count {
            return "Any workday"
        }
        return selected
            .map { String($0.name.prefix(3)) }
            .joined(separator: ", ")
    }

    private var workPolicyFooter: String {
        switch requirementType {
        case .fixedMonthlyDays:
            prorateFixedTarget
                ? "Full-day leave lowers the target when it removes an eligible workday."
                : "Full-day leave does not change the fixed target."
        case .percentageOfEligibleDays:
            "The target is rounded up from eligible workdays."
        }
    }
}

struct SettingsWorkdaysView: View {
    let workdays: [SettingsWorkdaySelection]

    var body: some View {
        Form {
            Section {
                ForEach(workdays) { workday in
                    Toggle(workday.name, isOn: workday.isSelected)
                }
            } footer: {
                Text("At least one workday is required.")
                    .foregroundStyle(Color.ds.textSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .appScreenBackground()
        .navigationTitle("Workdays")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SettingsPreferredOfficeDaysView: View {
    let workdays: [SettingsWorkdaySelection]

    var body: some View {
        Form {
            Section {
                ForEach(workdays) { workday in
                    Toggle(workday.name, isOn: workday.isSelected)
                }
            } footer: {
                Text("Suggest Days uses these first, then fills any remaining need chronologically.")
                    .foregroundStyle(Color.ds.textSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .appScreenBackground()
        .navigationTitle("Preferred Office Days")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SettingsReviewReminderSection: View {
    @Environment(\.openURL) private var openURL
    @State private var reminderService = ReviewReminderService()
    @State private var isUpdating = false

    private var isScheduled: Bool {
        if case .scheduled = reminderService.status {
            return true
        }
        return false
    }

    private var needsSystemSettings: Bool {
        reminderService.status == .authorizationDenied
    }

    var body: some View {
        Section {
            Toggle(
                "Weekly reminder",
                isOn: Binding(
                    get: { isScheduled },
                    set: updateReminder
                )
            )
            .disabled(isUpdating)
            .accessibilityIdentifier("settings.reviewReminder")

            if isUpdating {
                HStack(spacing: AppSpacing.sm) {
                    ProgressView()
                    Text("Updating reminder…")
                        .foregroundStyle(Color.ds.textSecondary)
                }
            } else if isScheduled {
                Label("Sunday, 6:00 pm", systemImage: "bell.badge.fill")
                    .foregroundStyle(Color.ds.success)
            }

            if needsSystemSettings,
               let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                Button("Open iOS Settings", systemImage: "gear") {
                    openURL(settingsURL)
                }
            }

            if let errorMessage = reminderService.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(AppTypography.caption)
                    .foregroundStyle(Color.ds.critical)
            }
        } header: {
            Text("Notifications")
                .foregroundStyle(Color.ds.textSecondary)
        } footer: {
            Text("Runs on device. Notification content is private.")
                .foregroundStyle(Color.ds.textSecondary)
        }
        .task {
            await reminderService.refreshStatus()
        }
    }

    private func updateReminder(_ shouldSchedule: Bool) {
        guard !isUpdating else { return }
        isUpdating = true

        Task {
            if shouldSchedule {
                let isAuthorized = await reminderService.requestAuthorizationInContext()
                if isAuthorized {
                    await reminderService.scheduleWeekly()
                }
            } else {
                await reminderService.cancelWeeklyReminder()
            }
            isUpdating = false
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
            Text("Privacy & data")
                .foregroundStyle(Color.ds.textSecondary)
        }
    }
}

struct SettingsWorkday: Identifiable {
    let id: Int
    let name: String

    static let all = [
        SettingsWorkday(id: 1, name: "Monday"),
        SettingsWorkday(id: 2, name: "Tuesday"),
        SettingsWorkday(id: 3, name: "Wednesday"),
        SettingsWorkday(id: 4, name: "Thursday"),
        SettingsWorkday(id: 5, name: "Friday"),
        SettingsWorkday(id: 6, name: "Saturday"),
        SettingsWorkday(id: 7, name: "Sunday")
    ]
}

struct SettingsWorkdaySelection: Identifiable {
    let id: Int
    let name: String
    let isSelected: Binding<Bool>
}

enum SettingsWeekdaySummary {
    static func text(
        for selectedISOWeekdays: [Int],
        from workdays: [SettingsWorkday]
    ) -> String {
        let selected = Set(selectedISOWeekdays)
        if selected == Set(1...5) {
            return "Mon–Fri"
        }
        if selected == Set(1...7) {
            return "Every day"
        }

        let names = workdays
            .filter { selected.contains($0.id) }
            .map { String($0.name.prefix(3)) }
        return names.isEmpty ? "Not set" : names.joined(separator: ", ")
    }
}
