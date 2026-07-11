import Foundation

protocol HolidayProvider {
    func holidays(for country: Country, jurisdictionId: String, year: Int) throws -> [PublicHoliday]
}

enum HolidayProviderError: Error, Equatable, LocalizedError {
    case missingFile(fileName: String)
    case unsupportedJurisdiction(countryCode: String, jurisdictionId: String)
    case unverifiedFile(fileName: String)
    case invalidData(fileName: String, reason: String)

    var errorDescription: String? {
        switch self {
        case .missingFile(let fileName):
            "Holiday data is unavailable for \(fileName).json."
        case .unsupportedJurisdiction(let countryCode, let jurisdictionId):
            "\(jurisdictionId) is not a supported \(countryCode) jurisdiction."
        case .unverifiedFile(let fileName):
            "Bundled holiday data has not been verified: \(fileName).json."
        case .invalidData(let fileName, let reason):
            "Invalid bundled holiday fixture \(fileName).json: \(reason)"
        }
    }
}
