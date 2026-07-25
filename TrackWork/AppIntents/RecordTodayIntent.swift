import AppIntents

struct RecordTodayIntent: AppIntent {
    static let title: LocalizedStringResource = "Record Today"
    static let description = IntentDescription(
        "Open Work Track to review and confirm today's attendance or full-day leave."
    )
    static let supportedModes: IntentModes = .foreground

    static var parameterSummary: some ParameterSummary {
        Summary("Review today as \(\.$status)")
    }

    @Parameter(
        title: "Status",
        description: "The attendance or full-day leave status to review for today.",
        requestValueDialog: "How should today be recorded?"
    )
    var status: TodayAttendanceIntentValue

    @MainActor
    func perform() async throws -> some IntentResult {
        WorkTrackAppIntentRouter.shared.submit(.recordToday(status: status))
        return .result()
    }
}
