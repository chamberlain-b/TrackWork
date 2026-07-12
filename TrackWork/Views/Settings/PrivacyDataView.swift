import SwiftData
import SwiftUI

struct PrivacyDataView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var isShowingDeleteConfirmation = false
    @State private var resetResult: ResetResult?

    private let dataManagementService = DataManagementService()

    var body: some View {
        List {
            Section {
                Label {
                    Text(
                        "Attendance, leave, notes, compliance settings, saved addresses and coordinates, and location events "
                            + "stay in this app's on-device storage."
                    )
                } icon: {
                    Image(systemName: "iphone.and.arrow.forward")
                        .foregroundStyle(Color.ds.accentPrimary)
                }

                Label {
                    Text("Work Track has no account, analytics, advertising, or app-managed cloud sync.")
                } icon: {
                    Image(systemName: "person.crop.circle.badge.xmark")
                        .foregroundStyle(Color.ds.info)
                }
            } header: {
                Text("On-Device Storage")
            } footer: {
                Text("Your device backup settings are controlled by iOS and may retain earlier app data.")
            }

            Section {
                Label {
                    Text(
                        "Address search and lookup are provided by Apple Maps when you choose them. Work Track's "
                            + "developer does not receive the search or location."
                    )
                } icon: {
                    Image(systemName: "map.fill")
                        .foregroundStyle(Color.ds.info)
                }

                Label {
                    Text(
                        "Current location is requested only for a one-time place selection. Work Track does not "
                            + "request Always access or track location continuously."
                    )
                } icon: {
                    Image(systemName: "location.fill")
                        .foregroundStyle(Color.ds.success)
                }
            } header: {
                Text("Location")
            }

            Section {
                Label {
                    Text("Default PDF and CSV reports exclude raw GPS coordinates and raw location events.")
                } icon: {
                    Image(systemName: "hand.raised.fill")
                        .foregroundStyle(Color.ds.success)
                }

                Label {
                    Text(
                        "Reports leave Work Track only when you share them. Copies saved in another app or service "
                            + "are controlled by that destination."
                    )
                } icon: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(Color.ds.info)
                }
            } header: {
                Text("Reports")
            }

            Section {
                Button(role: .destructive) {
                    isShowingDeleteConfirmation = true
                } label: {
                    Label("Delete All On-Device Data", systemImage: "trash")
                }
                .accessibilityIdentifier("privacyData.deleteAll")

                if let resetResult {
                    Label(resetResult.message, systemImage: resetResult.systemImage)
                        .foregroundStyle(resetResult.color)
                        .accessibilityIdentifier("privacyData.resetStatus")
                }
            } header: {
                Text("Delete Data")
            } footer: {
                Text(
                    "Resetting restores a fresh default compliance rule. It does not revoke location permission "
                        + "in iOS Settings or remove report copies you shared elsewhere."
                )
            }
        }
        .navigationTitle("Privacy & Data")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete all on-device data?", isPresented: $isShowingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}

            Button("Delete All Data", role: .destructive) {
                resetUserData()
            }
            .accessibilityIdentifier("privacyData.confirmDeleteAll")
        } message: {
            Text(
                "This permanently deletes attendance, leave, notes, manual overrides, compliance settings, "
                    + "custom excluded days, saved home and office locations, stored location events, custom "
                    + "holiday edits, and generated reports from this device."
            )
        }
    }

    private func resetUserData() {
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
            "On-device data was deleted and default settings were restored."
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
}
