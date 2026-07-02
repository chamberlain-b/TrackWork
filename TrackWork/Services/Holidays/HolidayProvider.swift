import Foundation

protocol HolidayProvider {
    func holidays(for country: Country, jurisdictionId: String, year: Int) throws -> [PublicHoliday]
}

enum HolidayProviderError: Error, Equatable, LocalizedError {
    case missingFile(fileName: String)
    case invalidData(fileName: String, reason: String)

    var errorDescription: String? {
        switch self {
        case .missingFile(let fileName):
            "Missing bundled holiday fixture: \(fileName).json"
        case .invalidData(let fileName, let reason):
            "Invalid bundled holiday fixture \(fileName).json: \(reason)"
        }
    }
}
