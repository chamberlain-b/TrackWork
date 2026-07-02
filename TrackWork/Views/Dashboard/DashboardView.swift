import SwiftUI

struct DashboardView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Dashboard",
                systemImage: "gauge.with.dots.needle.bottom.50percent",
                description: Text("Monthly attendance and compliance summaries will appear here.")
            )
            .navigationTitle("Dashboard")
        }
    }
}

#Preview {
    DashboardView()
}
