import SwiftData
import SwiftUI

struct ContentView: View {
    @State private var selectedTab: AppTab = .summary

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Summary", systemImage: "house.fill", value: AppTab.summary) {
                DashboardView(
                    onOpenCalendar: { selectedTab = .calendar },
                    onOpenSettings: { selectedTab = .settings }
                )
            }

            Tab("Calendar", systemImage: "calendar", value: AppTab.calendar) {
                MonthCalendarView()
            }

            Tab("History", systemImage: "list.bullet.rectangle", value: AppTab.history) {
                RecordsView()
            }

            Tab("Insights", systemImage: "chart.xyaxis.line", value: AppTab.insights) {
                InsightsHubView()
            }

            Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
                SettingsView()
            }
        }
    }
}

private enum AppTab: Hashable {
    case summary
    case calendar
    case history
    case insights
    case settings
}

private struct InsightsHubView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        ComplianceView(usesNavigationStack: false)
                    } label: {
                        InsightsDestinationRow(
                            systemImage: "target",
                            title: "Compliance",
                            subtitle: "Review a period and compare your result with a threshold",
                            color: Color.ds.accentPrimary
                        )
                    }
                } header: {
                    Text("Progress")
                }

                Section {
                    NavigationLink {
                        ExportView(usesNavigationStack: false)
                    } label: {
                        InsightsDestinationRow(
                            systemImage: "square.and.arrow.up",
                            title: "Export reports",
                            subtitle: "Create a private PDF or spreadsheet-compatible report",
                            color: Color.ds.info
                        )
                    }
                    .accessibilityIdentifier("insights.export")
                } header: {
                    Text("Reports")
                } footer: {
                    Text("Reports exclude raw location events and GPS coordinates by default.")
                }
            }
            .scrollContentBackground(.hidden)
            .appScreenBackground()
            .navigationTitle("Insights")
        }
    }
}

private struct InsightsDestinationRow: View {
    let systemImage: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(title)
                    .font(AppTypography.headline)
                    .foregroundStyle(Color.ds.textPrimary)

                Text(subtitle)
                    .font(AppTypography.caption)
                    .foregroundStyle(Color.ds.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, AppSpacing.xxs)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewData.modelContainer())
}
