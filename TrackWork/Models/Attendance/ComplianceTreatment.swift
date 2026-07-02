import Foundation

enum ComplianceTreatment: String, Codable, CaseIterable, Identifiable {
    case countsAsOffice
    case countsAsHome
    case excludedFromRequirement
    case requiresReview

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .countsAsOffice:
            "Counts as office"
        case .countsAsHome:
            "Counts as home"
        case .excludedFromRequirement:
            "Excluded from requirement"
        case .requiresReview:
            "Requires review"
        }
    }
}
