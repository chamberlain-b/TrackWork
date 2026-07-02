import Foundation

enum AttendanceClassification: String, Codable, CaseIterable, Identifiable {
    case office
    case home
    case mixed
    case annualLeave
    case sickLeave
    case publicHoliday
    case weekend
    case nonWorkingDay
    case unknown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .office:
            "Office"
        case .home:
            "Home"
        case .mixed:
            "Mixed"
        case .annualLeave:
            "Annual leave"
        case .sickLeave:
            "Sick leave"
        case .publicHoliday:
            "Public holiday"
        case .weekend:
            "Weekend"
        case .nonWorkingDay:
            "Non-working day"
        case .unknown:
            "Unknown"
        }
    }
}
