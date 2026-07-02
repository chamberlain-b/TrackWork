import Foundation

enum RequirementType: String, Codable, CaseIterable, Identifiable {
    case fixedMonthlyDays
    case percentageOfEligibleDays

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fixedMonthlyDays:
            "Fixed monthly days"
        case .percentageOfEligibleDays:
            "Percentage of eligible days"
        }
    }
}
