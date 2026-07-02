import Foundation

struct Jurisdiction: Codable, Hashable, Identifiable {
    let id: String
    let country: Country
    let displayName: String
    let shortName: String
}
