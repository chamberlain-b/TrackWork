import SwiftData
import SwiftUI

@main
struct TrackWorkApp: App {
    var body: some Scene {
        WindowGroup {
            AppRouter()
        }
        .modelContainer(for: [
            AttendanceDay.self,
            LeaveRecord.self,
            ManualAdjustment.self,
            ComplianceRule.self,
            Place.self,
            LocationEvent.self,
            PublicHoliday.self
        ])
    }
}
