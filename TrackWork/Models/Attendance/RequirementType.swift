import Foundation

enum RequirementType: String, Codable, CaseIterable, Identifiable {
    case fixedMonthlyDays
    case percentageOfEligibleDays

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fixedMonthlyDays:
            "Fixed office days"
        case .percentageOfEligibleDays:
            "Percentage of workdays"
        }
    }
}
