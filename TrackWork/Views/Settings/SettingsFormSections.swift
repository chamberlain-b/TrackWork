import SwiftUI
import UIKit

struct SettingsLocationSection: View {
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

            NavigationLink {
                RecentLocationEventsView()
            } label: {
                Label("Location Events", systemImage: "list.bullet.rectangle")
            }
        } header: {
            Text("Location")
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

            Picker("State or region", selection: $jurisdictionId) {
                ForEach(availableJurisdictions) { jurisdiction in
                    Text(jurisdiction.displayName)
                        .tag(jurisdiction.id)
                }
            }
            .accessibilityIdentifier("settings.jurisdiction")
        } header: {
            Text("Public holidays")
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
            Picker("Target type", selection: $requirementType) {
                ForEach(RequirementType.allCases) { requirementType in
                    Text(requirementType.displayName)
                        .tag(requirementType)
                }
            }
            .accessibilityIdentifier("settings.requirementType")

            if requirementType == .fixedMonthlyDays {
                LabeledContent("Days per period") {
                    TextField("Days", value: $fixedRequiredDays, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .accessibilityIdentifier("settings.fixedRequiredDays")
                }

                Toggle("Reduce for full-day leave", isOn: $prorateFixedTarget)
                    .accessibilityIdentifier("settings.prorateFixedTarget")
            } else {
                LabeledContent("Required office rate") {
                    HStack(spacing: AppSpacing.xxs) {
                        TextField(
                            "Percent",
                            value: $requiredPercentageInput,
                            format: .number.precision(.fractionLength(0...2))
                        )
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 72)

                        Text("%")
                            .foregroundStyle(Color.ds.textSecondary)
                    }
                }
            }
        } header: {
            Text("Office target")
        } footer: {
            if requirementType == .fixedMonthlyDays {
                Text("When enabled, full-day leave lowers the target.")
            } else {
                Text("Based on eligible workdays.")
            }
        }
    }
}

struct SettingsWorkScheduleSection: View {
    @Binding var minimumOfficeMinutes: Int
    let workdays: [SettingsWorkdaySelection]

    var body: some View {
        Section {
            NavigationLink {
                SettingsWorkdaysView(workdays: workdays)
            } label: {
                LabeledContent("Workdays", value: selectedWorkdaysSummary)
            }
            .accessibilityIdentifier("settings.workdays")

            LabeledContent("Minimum office time") {
                HStack(spacing: AppSpacing.xxs) {
                    TextField("Minutes", value: $minimumOfficeMinutes, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 72)

                    Text("min")
                        .foregroundStyle(Color.ds.textSecondary)
                }
            }
        } header: {
            Text("Work schedule")
        } footer: {
            Text("For days split between home and office.")
        }
    }

    private var selectedWorkdaysSummary: String {
        let selectedIds = workdays
            .filter { $0.isSelected.wrappedValue }
            .map(\.id)

        if selectedIds == [1, 2, 3, 4, 5] {
            return "Mon–Fri"
        }

        if selectedIds.count == 7 {
            return "Every day"
        }

        return "\(selectedIds.count) days"
    }
}

private struct SettingsWorkdaysView: View {
    let workdays: [SettingsWorkdaySelection]

    var body: some View {
        Form {
            Section {
                ForEach(workdays) { workday in
                    Toggle(workday.name, isOn: workday.isSelected)
                }
            } footer: {
                Text("At least one workday is required.")
            }
        }
        .scrollContentBackground(.hidden)
        .appScreenBackground()
        .navigationTitle("Workdays")
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
            Text("Reminder")
        } footer: {
            Text("Runs on device. Notification content is private.")
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

struct SettingsHolidayCoverageSection: View {
    var body: some View {
        Section {
            Label(HolidayCoverage.statusText, systemImage: "checkmark.seal.fill")
                .foregroundStyle(Color.ds.success)
        } header: {
            Text("Holiday data")
        } footer: {
            Text("Update the app for later years.")
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
            Text("Data")
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
