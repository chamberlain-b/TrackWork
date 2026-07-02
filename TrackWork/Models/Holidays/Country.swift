import Foundation

enum Country: String, Codable, CaseIterable, Identifiable {
    case australia = "AU"
    case newZealand = "NZ"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .australia:
            "Australia"
        case .newZealand:
            "New Zealand"
        }
    }
}
