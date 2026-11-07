import SwiftData
import SwiftUI

struct PrivacyDataView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppPrivacyLockService.self) private var privacyLockService
    @Environment(LocationTrackingService.self) private var locationTrackingService

    @State private var isShowingDeleteConfirmation = false
    @State private var resetResult: ResetResult?
    @State private var reviewReminderService = ReviewReminderService()

    private let dataManagementService = DataManagementService()

    var body: some View {
        List {
            Section {
                Toggle(
                    "Require device authentication",
                    isOn: Binding(
                        get: { privacyLockService.isEnabled },
                        set: updatePrivacyLock
                    )
                )
                .disabled(privacyLockService.isAuthenticating)
                .accessibilityIdentifier("privacyData.appLock")

                if privacyLockService.isAuthenticating {
                    HStack(spacing: AppSpacing.sm) {
                        ProgressView()
                        Text("Waiting for authentication…")
                            .foregroundStyle(Color.ds.textSecondary)
                    }
                }

                if let errorMessage = privacyLockService.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(AppTypography.caption)
                        .foregroundStyle(Color.ds.critical)
                }
            } header: {
                Text("App Lock")
            } footer: {
                Text("Uses Face ID, Touch ID or your device passcode after leaving the app.")
            }

            Section {
                Label {
                    Text(
                        "Attendance, leave, notes, settings and saved locations stay on this device."
                    )
                } icon: {
                    Image(systemName: "iphone.and.arrow.forward")
                        .foregroundStyle(Color.ds.interactionPrimary)
                }

                Label {
                    Text("No account, analytics, advertising or app-managed cloud sync.")
                } icon: {
                    Image(systemName: "person.crop.circle.badge.xmark")
                        .foregroundStyle(Color.ds.info)
                }
            } header: {
                Text("Storage")
            } footer: {
                Text("iOS backups may retain earlier app data.")
            }

            Section {
                Label {
                    Text("Address search uses Apple Maps.")
                } icon: {
                    Image(systemName: "map.fill")
                        .foregroundStyle(Color.ds.info)
                }

                Label {
                    Text("Check In uses one location sample, then discards it.")
                } icon: {
                    Image(systemName: "location.fill")
                        .foregroundStyle(Color.ds.success)
                }

                Label {
                    Text("Automatic Attendance uses saved-area events, not continuous GPS.")
                } icon: {
                    Image(systemName: "location.viewfinder")
                        .foregroundStyle(Color.ds.info)
                }
            } header: {
                Text("Location")
            }

            Section {
                Label {
                    Text("Standard reports exclude coordinates and location events.")
                } icon: {
                    Image(systemName: "hand.raised.fill")
                        .foregroundStyle(Color.ds.success)
                }

                Label {
                    Text("Shared copies are controlled by the destination app.")
                } icon: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(Color.ds.info)
                }
            } header: {
                Text("Reports")
            }

            Section {
                NavigationLink {
                    PortableBackupView()
                } label: {
                    Label("Backup & Restore", systemImage: "externaldrive.badge.timemachine")
                }
                .accessibilityIdentifier("privacyData.backup")
            } header: {
                Text("Backup")
            } footer: {
                Text("JSON backups are not encrypted.")
            }

            Section {
                Button(role: .destructive) {
                    isShowingDeleteConfirmation = true
                } label: {
                    Label("Delete All On-Device Data", systemImage: "trash")
                        .foregroundStyle(Color.ds.critical)
                }
                .tint(Color.ds.critical)
                .accessibilityIdentifier("privacyData.deleteAll")

                if let resetResult {
                    Label(resetResult.message, systemImage: resetResult.systemImage)
                        .foregroundStyle(resetResult.color)
                        .accessibilityIdentifier("privacyData.resetStatus")
                }
            } header: {
                Text("Delete data")
            } footer: {
                Text("Does not revoke iOS location access or delete shared reports.")
            }
        }
        .scrollContentBackground(.hidden)
        .appScreenBackground()
        .navigationTitle("Privacy & Data")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete all on-device data?", isPresented: $isShowingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}

            Button("Delete All Data", role: .destructive) {
                Task { await resetUserData() }
            }
            .accessibilityIdentifier("privacyData.confirmDeleteAll")
        } message: {
            Text(
                "Deletes all Work Track records, settings, locations, events, exports and plans from this device. "
                    + "Automatic Attendance and reminders are turned off. This cannot be undone."
            )
        }
    }

    private func updatePrivacyLock(_ shouldEnable: Bool) {
        Task {
            await privacyLockService.setEnabled(shouldEnable)
        }
    }

    private func resetUserData() async {
        locationTrackingService.setAutomaticTrackingEnabled(false, for: [])
        await reviewReminderService.cancelWeeklyReminder()

        do {
            try dataManagementService.resetUserData(in: modelContext)
            resetResult = .success
        } catch {
            resetResult = .failure
        }
    }
}

private enum ResetResult {
    case success
    case failure

    var message: String {
        switch self {
        case .success:
            "All on-device data was deleted. Automation and reminders are off."
        case .failure:
            "Work Track could not delete all on-device data. Try again."
        }
    }

    var systemImage: String {
        switch self {
        case .success:
            "checkmark.circle.fill"
        case .failure:
            "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .success:
            Color.ds.success
        case .failure:
            Color.ds.critical
        }
    }
}

#Preview {
    NavigationStack {
        PrivacyDataView()
    }
    .modelContainer(PreviewData.modelContainer())
    .environment(AppPrivacyLockService())
    .environment(LocationTrackingService())
}
