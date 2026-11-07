import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var referenceDate = AppLaunchConfiguration.dashboardReferenceDate
    @State private var selectedTab: AppTab = .summary
    @State private var reportingSelection = ReportingPeriodSelection(referenceDate: AppLaunchConfiguration.dashboardReferenceDate)
    @State private var insightsSection: InsightsSection = .overview
    @State private var appIntentRouter = WorkTrackAppIntentRouter.shared
    @State private var intentPresentation: IntentPresentation?

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: AppTab.summary) {
                DashboardView(
                    onOpenCalendar: { selectedTab = .calendar },
                    onOpenSettings: { selectedTab = .settings },
                    referenceDate: referenceDate,
                    reportingSelection: reportingSelection,
                    onOpenInsights: { section in
                        insightsSection = section
                        selectedTab = .insights
                    }
                )
            }

            Tab("Calendar", systemImage: "calendar", value: AppTab.calendar) {
                MonthCalendarView(referenceDate: referenceDate)
            }

            Tab("Insights", systemImage: "chart.bar.xaxis", value: AppTab.insights) {
                InsightsView(selection: reportingSelection,
                             referenceDate: referenceDate,
                             section: $insightsSection)
            }

            Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
                SettingsView()
            }
        }
        .tint(Color.ds.interactionPrimary)
        .task {
            handlePendingIntent()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                referenceDate = AppLaunchConfiguration.dashboardReferenceDate
            }
        }
        .task {
            // iOS posts this for midnight and significant clock/time-zone changes.
            // Refresh day-based views without a timer or changing the selected report period.
            for await _ in NotificationCenter.default.notifications(
                named: UIApplication.significantTimeChangeNotification
            ).map({ _ in () }) {
                referenceDate = AppLaunchConfiguration.dashboardReferenceDate
            }
        }
        .onChange(of: appIntentRouter.pendingHandoff) { _, _ in
            handlePendingIntent()
        }
        .sheet(item: $intentPresentation) { presentation in
            NavigationStack {
                switch presentation {
                case .recordToday(let status):
                    TodayIntentReviewView(status: status)
                case .reviewPendingDays:
                    ReviewQueueView()
                }
            }
        }
    }

    private func handlePendingIntent() {
        guard let handoff = appIntentRouter.pendingHandoff else {
            return
        }

        selectedTab = .summary
        switch handoff.action {
        case .recordToday(let status):
            intentPresentation = .recordToday(status)
        case .reviewPendingDays:
            intentPresentation = .reviewPendingDays
        }
        appIntentRouter.clearHandoff(id: handoff.id)
    }
}

private enum AppTab: Hashable {
    case summary
    case calendar
    case insights
    case settings
}

private enum IntentPresentation: Identifiable {
    case recordToday(TodayAttendanceIntentValue)
    case reviewPendingDays

    var id: String {
        switch self {
        case .recordToday(let status): "record-\(status.rawValue)"
        case .reviewPendingDays: "review"
        }
    }
}

private struct TodayIntentReviewView: View {
    @Query(sort: \AttendanceDay.date) private var attendanceDays: [AttendanceDay]
    @Query(sort: \LeaveRecord.date) private var leaveRecords: [LeaveRecord]
    @Query(sort: \PublicHoliday.date) private var publicHolidays: [PublicHoliday]
    @Query(sort: \CustomExcludedDay.date) private var customExcludedDays: [CustomExcludedDay]
    @Query(sort: \ComplianceRule.createdAt) private var complianceRules: [ComplianceRule]

    let status: TodayAttendanceIntentValue

    private let date = Date.now
    private let calendar = Calendar.workTrackCalendar
    private let ruleResolver = ComplianceRuleResolver()

    var body: some View {
        DayDetailView(
            date: date,
            attendanceDay: attendanceDays.first { calendar.isDate($0.date, inSameDayAs: date) },
            leaveRecord: leaveRecords.first { calendar.isDate($0.date, inSameDayAs: date) },
            publicHoliday: ActiveJurisdictionHolidayResolver.holiday(
                on: date,
                from: publicHolidays,
                jurisdictionId: activeRule.jurisdictionId,
                calendar: calendar
            ),
            customExcludedDay: customExcludedDays.first { calendar.isDate($0.date, inSameDayAs: date) },
            proposedStatus: status.attendanceClassification
        )
    }

    private var activeRule: ComplianceRule {
        ruleResolver.rule(for: date, from: complianceRules) ?? ComplianceRule()
    }
}

private extension TodayAttendanceIntentValue {
    var attendanceClassification: AttendanceClassification {
        switch self {
        case .office: .office
        case .home: .home
        case .annualLeave: .annualLeave
        case .sickLeave: .sickLeave
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewData.modelContainer())
}
