import Foundation

enum OverrideReason: String, Codable, CaseIterable, Identifiable {
    case forgotWorkPass
    case phoneLocationIncorrect
    case phoneBatteryFlat
    case manualCorrection
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .forgotWorkPass:
            "Forgot work pass"
        case .phoneLocationIncorrect:
            "Phone location incorrect"
        case .phoneBatteryFlat:
            "Phone battery flat"
        case .manualCorrection:
            "Manual correction"
        case .other:
            "Other"
        }
    }
}
