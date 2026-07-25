import XCTest
@testable import TrackWork

@MainActor
final class ReviewReminderServiceTests: XCTestCase {
    func testSchedulingDoesNotRequestAuthorizationImplicitly() async {
        let provider = FakeReviewReminderNotificationProvider()
        let service = ReviewReminderService(notificationProvider: provider)

        let didSchedule = await service.scheduleWeekly()

        XCTAssertFalse(didSchedule)
        XCTAssertEqual(service.status, .authorizationRequired)
        XCTAssertEqual(provider.authorizationRequestCount, 0)
        XCTAssertTrue(provider.scheduledRequests.isEmpty)
    }

    func testExplicitAuthorizationThenSchedulesPrivacySafeWeeklyReminder() async throws {
        let provider = FakeReviewReminderNotificationProvider()
        let service = ReviewReminderService(notificationProvider: provider)

        let didAuthorize = await service.requestAuthorizationInContext()
        XCTAssertTrue(didAuthorize)
        let schedule = ReviewReminderWeeklySchedule(isoWeekday: 5, hour: 17, minute: 30)
        let didSchedule = await service.scheduleWeekly(schedule)
        XCTAssertTrue(didSchedule)

        XCTAssertEqual(provider.authorizationRequestCount, 1)
        let request = try XCTUnwrap(provider.scheduledRequests.first)
        XCTAssertEqual(request.identifier, ReviewReminderService.reminderIdentifier)
        XCTAssertEqual(request.schedule, schedule)
        XCTAssertEqual(request.title, "Review Work Track")
        XCTAssertEqual(request.body, "Open the app when convenient to review your recent days.")
        XCTAssertFalse(request.title.localizedCaseInsensitiveContains("office"))
        XCTAssertFalse(request.body.localizedCaseInsensitiveContains("home"))
        XCTAssertFalse(request.body.localizedCaseInsensitiveContains("location"))
        XCTAssertEqual(service.status, .scheduled(schedule))
    }

    func testDeniedAuthorizationReportsSettingsPathWithoutScheduling() async {
        let provider = FakeReviewReminderNotificationProvider()
        provider.authorizationStateValue = .denied
        let service = ReviewReminderService(notificationProvider: provider)

        let didAuthorize = await service.requestAuthorizationInContext()
        XCTAssertFalse(didAuthorize)
        XCTAssertEqual(service.status, .authorizationDenied)
        XCTAssertEqual(provider.authorizationRequestCount, 0)
        XCTAssertTrue(provider.scheduledRequests.isEmpty)
        XCTAssertTrue(service.errorMessage?.contains("iOS Settings") == true)
    }

    func testRefreshAndCancelReflectPendingSchedule() async {
        let schedule = ReviewReminderWeeklySchedule(isoWeekday: 1, hour: 8, minute: 15)
        let provider = FakeReviewReminderNotificationProvider()
        provider.authorizationStateValue = .authorized
        provider.pendingSchedule = schedule
        let service = ReviewReminderService(notificationProvider: provider)

        await service.refreshStatus()
        XCTAssertEqual(service.status, .scheduled(schedule))

        await service.cancelWeeklyReminder()
        XCTAssertEqual(provider.cancelledIdentifiers, [ReviewReminderService.reminderIdentifier])
        XCTAssertEqual(service.status, .notScheduled)
    }

    func testWeeklyScheduleUsesISOWeekdays() {
        XCTAssertEqual(SystemReviewReminderProvider.calendarWeekday(fromISOWeekday: 1), 2)
        XCTAssertEqual(SystemReviewReminderProvider.calendarWeekday(fromISOWeekday: 7), 1)
        XCTAssertEqual(SystemReviewReminderProvider.isoWeekday(fromCalendarWeekday: 2), 1)
        XCTAssertEqual(SystemReviewReminderProvider.isoWeekday(fromCalendarWeekday: 1), 7)
        XCTAssertNil(SystemReviewReminderProvider.isoWeekday(fromCalendarWeekday: 0))
    }
}

@MainActor
private final class FakeReviewReminderNotificationProvider: ReviewReminderNotificationProviding {
    var authorizationStateValue: ReviewReminderAuthorizationState = .notDetermined
    var authorizationRequestResult = true
    var pendingSchedule: ReviewReminderWeeklySchedule?
    private(set) var authorizationRequestCount = 0
    private(set) var scheduledRequests: [ReviewReminderNotificationRequest] = []
    private(set) var cancelledIdentifiers: [String] = []

    func authorizationState() async -> ReviewReminderAuthorizationState {
        authorizationStateValue
    }

    func requestAuthorization() async throws -> Bool {
        authorizationRequestCount += 1
        if authorizationRequestResult {
            authorizationStateValue = .authorized
        }
        return authorizationRequestResult
    }

    func pendingWeeklySchedule(identifier: String) async -> ReviewReminderWeeklySchedule? {
        pendingSchedule
    }

    func schedule(_ request: ReviewReminderNotificationRequest) async throws {
        scheduledRequests.append(request)
        pendingSchedule = request.schedule
    }

    func cancel(identifier: String) {
        cancelledIdentifiers.append(identifier)
        pendingSchedule = nil
    }
}
