import SwiftData
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "gauge.with.dots.needle.bottom.50percent")
                }

            MonthCalendarView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }

            RecordsView()
                .tabItem {
                    Label("Records", systemImage: "list.bullet.rectangle")
                }

            ComplianceView()
                .tabItem {
                    Label("Compliance", systemImage: "target")
                }

            ExportView()
                .tabItem {
                    Label("Export", systemImage: "square.and.arrow.up")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewData.modelContainer())
}
