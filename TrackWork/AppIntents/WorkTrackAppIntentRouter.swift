import Foundation
import Observation

@MainActor
@Observable
final class WorkTrackAppIntentRouter {
    struct Handoff: Equatable, Identifiable {
        let id = UUID()
        let action: Action
    }

    enum Action: Equatable {
        case recordToday(status: TodayAttendanceIntentValue)
        case reviewPendingDays
    }

    static let shared = WorkTrackAppIntentRouter()

    private(set) var pendingHandoff: Handoff?

    private init() {}

    func submit(_ action: Action) {
        pendingHandoff = Handoff(action: action)
    }

    func clearHandoff(id: UUID) {
        guard pendingHandoff?.id == id else {
            return
        }

        pendingHandoff = nil
    }
}
