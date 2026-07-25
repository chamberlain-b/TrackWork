import AppIntents

struct WorkTrackAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RecordTodayIntent(),
            phrases: [
                "Record today as \(\.$status) in \(.applicationName)",
                "Log \(\.$status) for today with \(.applicationName)"
            ],
            shortTitle: "Record Today",
            systemImageName: "calendar.badge.plus"
        )

        AppShortcut(
            intent: ReviewPendingDaysIntent(),
            phrases: [
                "Review pending days in \(.applicationName)",
                "Review unconfirmed workdays in \(.applicationName)"
            ],
            shortTitle: "Review Pending Days",
            systemImageName: "checklist"
        )
    }
}
