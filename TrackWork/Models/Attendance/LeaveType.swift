import Foundation

enum LeaveType: String, Codable, CaseIterable, Identifiable {
    case annualLeave
    case sickLeave

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .annualLeave:
            "Annual leave"
        case .sickLeave:
            "Sick leave"
        }
    }
}
