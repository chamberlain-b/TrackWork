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
}
