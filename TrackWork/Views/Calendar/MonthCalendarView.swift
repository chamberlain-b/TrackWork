import SwiftUI

struct MonthCalendarView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Calendar",
                systemImage: "calendar",
                description: Text("Attendance days and manual edits will appear here.")
            )
            .navigationTitle("Calendar")
        }
    }
}

#Preview {
    MonthCalendarView()
}
