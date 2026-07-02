import Foundation

enum LeaveDuration: String, Codable, CaseIterable, Identifiable {
    case fullDay
    case halfDayAM
    case halfDayPM

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fullDay:
            "Full day"
        case .halfDayAM:
            "Half day AM"
        case .halfDayPM:
            "Half day PM"
        }
    }
}
