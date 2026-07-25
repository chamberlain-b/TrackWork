import Foundation
import LocalAuthentication
import Observation

enum DeviceOwnerAuthenticationAvailability: Equatable {
    case available
    case unavailable(String)
}

@MainActor
protocol DeviceOwnerAuthenticationProviding {
    func availability() -> DeviceOwnerAuthenticationAvailability
    func authenticate(reason: String) async throws -> Bool
}

@MainActor
struct LocalAuthenticationProvider: DeviceOwnerAuthenticationProviding {
    func availability() -> DeviceOwnerAuthenticationAvailability {
        let context = LAContext()
        var evaluationError: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &evaluationError) else {
            return .unavailable(Self.availabilityMessage(for: evaluationError))
        }

        return .available
    }

    func authenticate(reason: String) async throws -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
    }

    private static func availabilityMessage(for error: NSError?) -> String {
        guard error?.domain == LAError.errorDomain,
              let code = error.flatMap({ LAError.Code(rawValue: $0.code) }) else {
            return "Device authentication is unavailable."
        }

        switch code {
        case .passcodeNotSet:
            return "Set a device passcode before enabling the privacy lock."
        case .biometryNotEnrolled:
            return "Set up Face ID or Touch ID, or confirm that a device passcode is available."
        case .biometryNotAvailable:
            return "Face ID or Touch ID is unavailable on this device."
        default:
            return "Device authentication is unavailable."
        }
    }
}

@MainActor
@Observable
final class AppPrivacyLockService {
    static let defaultPreferenceKey = "privacy.appLock.isEnabled"

    private let authenticator: any DeviceOwnerAuthenticationProviding
    private let defaults: UserDefaults
    private let preferenceKey: String
    private let bypassesLockForUITesting: Bool

    private(set) var isEnabled: Bool
    private(set) var isLocked: Bool
    private(set) var isContentObscured: Bool
    private(set) var isAuthenticating = false
    private(set) var errorMessage: String?

    init(
        authenticator: (any DeviceOwnerAuthenticationProviding)? = nil,
        defaults: UserDefaults? = nil,
        preferenceKey: String? = nil,
        isUITesting: Bool? = nil
    ) {
        let resolvedDefaults = defaults ?? .standard
        let resolvedPreferenceKey = preferenceKey ?? Self.defaultPreferenceKey
        let resolvedIsUITesting = isUITesting ?? AppLaunchConfiguration.isUITesting

        self.authenticator = authenticator ?? LocalAuthenticationProvider()
        self.defaults = resolvedDefaults
        self.preferenceKey = resolvedPreferenceKey
        self.bypassesLockForUITesting = resolvedIsUITesting

        // UI automation must never become trapped behind an operating-system authentication sheet.
        let storedPreference = resolvedDefaults.bool(forKey: resolvedPreferenceKey)
        self.isEnabled = storedPreference && !resolvedIsUITesting
        self.isLocked = storedPreference && !resolvedIsUITesting
        self.isContentObscured = storedPreference && !resolvedIsUITesting
    }

    var authenticationAvailability: DeviceOwnerAuthenticationAvailability {
        authenticator.availability()
    }

    @discardableResult
    func setEnabled(_ enabled: Bool) async -> Bool {
        errorMessage = nil

        guard !bypassesLockForUITesting else {
            isEnabled = false
            isLocked = false
            isContentObscured = false
            return false
        }

        guard enabled != isEnabled else {
            return true
        }

        guard enabled else {
            defaults.set(false, forKey: preferenceKey)
            isEnabled = false
            isLocked = false
            isContentObscured = false
            return true
        }

        let availability = authenticator.availability()
        guard case .available = availability else {
            if case .unavailable(let message) = availability {
                errorMessage = message
            }
            return false
        }

        guard await authenticate(reason: "Enable the Work Track privacy lock.") else {
            return false
        }

        defaults.set(true, forKey: preferenceKey)
        isEnabled = true
        isLocked = false
        isContentObscured = false
        return true
    }

    func lockAndObscure() {
        guard isEnabled, !bypassesLockForUITesting else {
            return
        }

        isLocked = true
        isContentObscured = true
        errorMessage = nil
    }

    func obscureWhileInactive() {
        guard isEnabled, !bypassesLockForUITesting else {
            return
        }

        isContentObscured = true
    }

    @discardableResult
    func unlockIfNeeded() async -> Bool {
        errorMessage = nil

        guard isEnabled, !bypassesLockForUITesting else {
            isLocked = false
            isContentObscured = false
            return true
        }

        guard isLocked else {
            isContentObscured = false
            return true
        }

        let availability = authenticator.availability()
        guard case .available = availability else {
            if case .unavailable(let message) = availability {
                errorMessage = message
            }
            return false
        }

        guard await authenticate(reason: "Unlock Work Track to view your attendance data.") else {
            return false
        }

        isLocked = false
        isContentObscured = false
        return true
    }

    func clearError() {
        errorMessage = nil
    }

    private func authenticate(reason: String) async -> Bool {
        guard !isAuthenticating else {
            return false
        }

        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            let didAuthenticate = try await authenticator.authenticate(reason: reason)
            if !didAuthenticate {
                errorMessage = "Device authentication did not complete."
            }
            return didAuthenticate
        } catch {
            errorMessage = Self.authenticationMessage(for: error)
            return false
        }
    }

    private static func authenticationMessage(for error: Error) -> String {
        let error = error as NSError
        guard error.domain == LAError.errorDomain,
              let code = LAError.Code(rawValue: error.code) else {
            return "Work Track could not verify your identity. Try again."
        }

        switch code {
        case .userCancel, .appCancel, .systemCancel:
            return "Authentication was cancelled."
        case .authenticationFailed:
            return "Your identity could not be verified. Try again."
        case .passcodeNotSet:
            return "Set a device passcode before enabling the privacy lock."
        case .biometryLockout:
            return "Face ID or Touch ID is locked. Use your device passcode to continue."
        default:
            return "Work Track could not verify your identity. Try again."
        }
    }
}
