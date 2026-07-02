import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Jurisdiction") {
                    LabeledContent("Country", value: "Australia")
                    LabeledContent("Region", value: "VIC")
                }

                Section("Compliance") {
                    LabeledContent("Period", value: "Calendar month")
                    LabeledContent("Requirement", value: "10 office days")
                }

                Section("Privacy") {
                    Text("Location tracking is not enabled yet.")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
