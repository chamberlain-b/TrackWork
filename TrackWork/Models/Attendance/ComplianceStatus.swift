import Foundation

enum ComplianceStatus: String, Codable, CaseIterable, Identifiable {
    case complete
    case onTrack
    case atRisk
    case impossible

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .complete:
            "Complete"
        case .onTrack:
            "On track"
        case .atRisk:
            "At risk"
        case .impossible:
            "Impossible"
        }
    }
}
