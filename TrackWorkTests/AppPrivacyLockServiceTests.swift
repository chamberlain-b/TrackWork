import XCTest
@testable import TrackWork

@MainActor
final class AppPrivacyLockServiceTests: XCTestCase {
    func testStoredOptInStartsLockedAndObscured() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(true, forKey: "test.lock")

        let service = AppPrivacyLockService(
            authenticator: FakeDeviceOwnerAuthenticator(),
            defaults: defaults,
            preferenceKey: "test.lock",
            isUITesting: false
        )

        XCTAssertTrue(service.isEnabled)
        XCTAssertTrue(service.isLocked)
        XCTAssertTrue(service.isContentObscured)
        XCTAssertFalse(service.isAuthenticating)
    }

    func testEnablingRequiresAuthenticationBeforePersistingOptIn() async throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let authenticator = FakeDeviceOwnerAuthenticator()
        let service = AppPrivacyLockService(
            authenticator: authenticator,
            defaults: defaults,
            preferenceKey: "test.lock",
            isUITesting: false
        )

        let didEnable = await service.setEnabled(true)

        XCTAssertTrue(didEnable)
        XCTAssertTrue(service.isEnabled)
        XCTAssertFalse(service.isLocked)
        XCTAssertFalse(service.isContentObscured)
        XCTAssertTrue(defaults.bool(forKey: "test.lock"))
        XCTAssertEqual(authenticator.authenticationReasons, ["Enable the Work Track privacy lock."])
    }

    func testLockRemainsObscuredUntilSuccessfulAuthentication() async throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(true, forKey: "test.lock")
        let authenticator = FakeDeviceOwnerAuthenticator()
        authenticator.authenticationResult = false
        let service = AppPrivacyLockService(
            authenticator: authenticator,
            defaults: defaults,
            preferenceKey: "test.lock",
            isUITesting: false
        )

        let firstUnlockSucceeded = await service.unlockIfNeeded()
        XCTAssertFalse(firstUnlockSucceeded)
        XCTAssertTrue(service.isLocked)
        XCTAssertTrue(service.isContentObscured)
        XCTAssertNotNil(service.errorMessage)

        authenticator.authenticationResult = true
        let secondUnlockSucceeded = await service.unlockIfNeeded()
        XCTAssertTrue(secondUnlockSucceeded)
        XCTAssertFalse(service.isLocked)
        XCTAssertFalse(service.isContentObscured)

        service.lockAndObscure()
        XCTAssertTrue(service.isLocked)
        XCTAssertTrue(service.isContentObscured)
    }

    func testUnavailableAuthenticationDoesNotPersistPreference() async throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let authenticator = FakeDeviceOwnerAuthenticator()
        authenticator.authenticationAvailability = .unavailable("Set a device passcode first.")
        let service = AppPrivacyLockService(
            authenticator: authenticator,
            defaults: defaults,
            preferenceKey: "test.lock",
            isUITesting: false
        )

        let didEnable = await service.setEnabled(true)
        XCTAssertFalse(didEnable)
        XCTAssertFalse(service.isEnabled)
        XCTAssertFalse(defaults.bool(forKey: "test.lock"))
        XCTAssertEqual(service.errorMessage, "Set a device passcode first.")
        XCTAssertTrue(authenticator.authenticationReasons.isEmpty)
    }

    func testUITestingBypassesPersistedLockWithoutChangingPreference() async throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(true, forKey: "test.lock")
        let authenticator = FakeDeviceOwnerAuthenticator()
        let service = AppPrivacyLockService(
            authenticator: authenticator,
            defaults: defaults,
            preferenceKey: "test.lock",
            isUITesting: true
        )

        XCTAssertFalse(service.isEnabled)
        XCTAssertFalse(service.isLocked)
        XCTAssertFalse(service.isContentObscured)
        let didEnable = await service.setEnabled(true)
        XCTAssertFalse(didEnable)
        XCTAssertTrue(defaults.bool(forKey: "test.lock"))
        XCTAssertTrue(authenticator.authenticationReasons.isEmpty)
    }

    private func makeDefaults() throws -> (UserDefaults, String) {
        let suiteName = "AppPrivacyLockServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }
}

@MainActor
private final class FakeDeviceOwnerAuthenticator: DeviceOwnerAuthenticationProviding {
    var authenticationAvailability: DeviceOwnerAuthenticationAvailability = .available
    var authenticationResult = true
    var authenticationError: Error?
    private(set) var authenticationReasons: [String] = []

    func availability() -> DeviceOwnerAuthenticationAvailability {
        authenticationAvailability
    }

    func authenticate(reason: String) async throws -> Bool {
        authenticationReasons.append(reason)
        if let authenticationError {
            throw authenticationError
        }
        return authenticationResult
    }
}
