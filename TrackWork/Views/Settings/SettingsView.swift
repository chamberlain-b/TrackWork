import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Settings",
                systemImage: "gearshape",
                description: Text("App preferences and privacy controls will be configured here.")
            )
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
