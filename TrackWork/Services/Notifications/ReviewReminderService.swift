import Foundation
import Observation
import UserNotifications

enum ReviewReminderAuthorizationState: Equatable {
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral
    case unavailable

    var permitsScheduling: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            true
        case .notDetermined, .denied, .unavailable:
            false
        }
    }
}

struct ReviewReminderWeeklySchedule: Equatable, Sendable {
    let isoWeekday: Int
    let hour: Int
    let minute: Int

    static let sundayEvening = ReviewReminderWeeklySchedule(isoWeekday: 7, hour: 18, minute: 0)

    var isValid: Bool {
        (1...7).contains(isoWeekday) && (0...23).contains(hour) && (0...59).contains(minute)
    }
}

struct ReviewReminderNotificationRequest: Equatable, Sendable {
    let identifier: String
    let title: String
    let body: String
    let schedule: ReviewReminderWeeklySchedule
}

enum ReviewReminderStatus: Equatable {
    case authorizationRequired
    case authorizationDenied
    case notScheduled
    case scheduled(ReviewReminderWeeklySchedule)
    case unavailable
}

@MainActor
protocol ReviewReminderNotificationProviding {
    func authorizationState() async -> ReviewReminderAuthorizationState
    func requestAuthorization() async throws -> Bool
    func pendingWeeklySchedule(identifier: String) async -> ReviewReminderWeeklySchedule?
    func schedule(_ request: ReviewReminderNotificationRequest) async throws
    func cancel(identifier: String)
}

@MainActor
final class SystemReviewReminderProvider: ReviewReminderNotificationProviding {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorizationState() async -> ReviewReminderAuthorizationState {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: Self.mapAuthorizationStatus(settings.authorizationStatus))
            }
        }
    }

    func requestAuthorization() async throws -> Bool {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            center.requestAuthorization(options: [.alert, .sound]) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func pendingWeeklySchedule(identifier: String) async -> ReviewReminderWeeklySchedule? {
        let requests: [UNNotificationRequest] = await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }

        guard let request = requests.first(where: { $0.identifier == identifier }),
              let trigger = request.trigger as? UNCalendarNotificationTrigger else {
            return nil
        }

        let components = trigger.dateComponents
        guard let calendarWeekday = components.weekday,
              let isoWeekday = Self.isoWeekday(fromCalendarWeekday: calendarWeekday),
              let hour = components.hour,
              let minute = components.minute else {
            return nil
        }

        let schedule = ReviewReminderWeeklySchedule(isoWeekday: isoWeekday, hour: hour, minute: minute)
        return schedule.isValid ? schedule : nil
    }

    func schedule(_ request: ReviewReminderNotificationRequest) async throws {
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.calendar = Calendar(identifier: .gregorian)
        dateComponents.weekday = Self.calendarWeekday(fromISOWeekday: request.schedule.isoWeekday)
        dateComponents.hour = request.schedule.hour
        dateComponents.minute = request.schedule.minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let notificationRequest = UNNotificationRequest(
            identifier: request.identifier,
            content: content,
            trigger: trigger
        )

        center.removePendingNotificationRequests(withIdentifiers: [request.identifier])
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(notificationRequest) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func cancel(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    static func calendarWeekday(fromISOWeekday isoWeekday: Int) -> Int {
        isoWeekday == 7 ? 1 : isoWeekday + 1
    }

    static func isoWeekday(fromCalendarWeekday calendarWeekday: Int) -> Int? {
        guard (1...7).contains(calendarWeekday) else {
            return nil
        }

        return calendarWeekday == 1 ? 7 : calendarWeekday - 1
    }

    nonisolated private static func mapAuthorizationStatus(
        _ status: UNAuthorizationStatus
    ) -> ReviewReminderAuthorizationState {
        switch status {
        case .notDetermined:
            .notDetermined
        case .denied:
            .denied
        case .authorized:
            .authorized
        case .provisional:
            .provisional
        case .ephemeral:
            .ephemeral
        @unknown default:
            .unavailable
        }
    }
}

@MainActor
@Observable
final class ReviewReminderService {
    static let reminderIdentifier = "worktrack.review-reminder.weekly"
    static let privacySafeTitle = "Review Work Track"
    static let privacySafeBody = "Open the app when convenient to review your recent days."

    private let notificationProvider: any ReviewReminderNotificationProviding

    private(set) var authorizationState: ReviewReminderAuthorizationState = .notDetermined
    private(set) var status: ReviewReminderStatus = .authorizationRequired
    private(set) var errorMessage: String?

    init(
        notificationProvider: (any ReviewReminderNotificationProviding)? = nil
    ) {
        self.notificationProvider = notificationProvider ?? SystemReviewReminderProvider()
    }

    func refreshStatus() async {
        errorMessage = nil
        authorizationState = await notificationProvider.authorizationState()

        switch authorizationState {
        case .notDetermined:
            status = .authorizationRequired
        case .denied:
            status = .authorizationDenied
        case .unavailable:
            status = .unavailable
        case .authorized, .provisional, .ephemeral:
            if let schedule = await notificationProvider.pendingWeeklySchedule(
                identifier: Self.reminderIdentifier
            ) {
                status = .scheduled(schedule)
            } else {
                status = .notScheduled
            }
        }
    }

    /// Call only from a user-initiated reminder setup screen after explaining the reminder's value.
    @discardableResult
    func requestAuthorizationInContext() async -> Bool {
        errorMessage = nil
        let currentState = await notificationProvider.authorizationState()
        authorizationState = currentState

        if currentState.permitsScheduling {
            await refreshStatus()
            return true
        }

        guard currentState != .denied else {
            status = .authorizationDenied
            errorMessage = "Notifications are off for Work Track. You can enable them in iOS Settings."
            return false
        }

        do {
            let granted = try await notificationProvider.requestAuthorization()
            await refreshStatus()
            if !granted {
                errorMessage = "Notifications were not enabled. You can continue without reminders."
            }
            return granted
        } catch {
            status = .unavailable
            errorMessage = "Work Track could not request notification access. Try again."
            return false
        }
    }

    /// Scheduling never prompts. Permission must be requested explicitly through requestAuthorizationInContext().
    @discardableResult
    func scheduleWeekly(_ requestedSchedule: ReviewReminderWeeklySchedule? = nil) async -> Bool {
        errorMessage = nil
        let schedule = requestedSchedule ?? .sundayEvening

        guard schedule.isValid else {
            errorMessage = "Choose a valid weekday and time for the reminder."
            return false
        }

        authorizationState = await notificationProvider.authorizationState()
        guard authorizationState.permitsScheduling else {
            switch authorizationState {
            case .denied:
                status = .authorizationDenied
                errorMessage = "Notifications are off for Work Track. You can enable them in iOS Settings."
            case .notDetermined:
                status = .authorizationRequired
                errorMessage = "Choose Enable Notifications before scheduling a reminder."
            case .unavailable:
                status = .unavailable
                errorMessage = "Notifications are unavailable on this device."
            case .authorized, .provisional, .ephemeral:
                break
            }
            return false
        }

        // Copy intentionally avoids attendance status, location, dates, and unresolved-day counts.
        let request = ReviewReminderNotificationRequest(
            identifier: Self.reminderIdentifier,
            title: Self.privacySafeTitle,
            body: Self.privacySafeBody,
            schedule: schedule
        )

        do {
            try await notificationProvider.schedule(request)
            status = .scheduled(schedule)
            return true
        } catch {
            errorMessage = "The weekly reminder could not be scheduled. Try again."
            return false
        }
    }

    func cancelWeeklyReminder() async {
        errorMessage = nil
        notificationProvider.cancel(identifier: Self.reminderIdentifier)
        await refreshStatus()
    }
}
