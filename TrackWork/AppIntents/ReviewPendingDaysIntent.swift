import AppIntents

struct ReviewPendingDaysIntent: AppIntent {
    static let title: LocalizedStringResource = "Review Pending Days"
    static let description = IntentDescription(
        "Open Work Track at the next workday that still needs confirmation."
    )
    static let supportedModes: IntentModes = .foreground

    static var parameterSummary: some ParameterSummary {
        Summary("Review workdays that need confirmation")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        WorkTrackAppIntentRouter.shared.submit(.reviewPendingDays)
        return .result()
    }
}
