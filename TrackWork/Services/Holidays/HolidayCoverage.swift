import Foundation

enum HolidayCoverage {
    struct Validation: Equatable {
        let requiredYears: [Int]
        let unsupportedYears: [Int]

        var isSupported: Bool {
            unsupportedYears.isEmpty
        }

        var userFacingMessage: String? {
            guard !isSupported else {
                return nil
            }

            let unavailableYears = unsupportedYears.map(String.init).joined(separator: ", ")
            return "Public holiday data is not bundled for \(unavailableYears). "
                + "Results for this range may be incomplete. Choose dates within \(HolidayCoverage.supportedYearsText)."
        }
    }

    static let supportedYears: Set<Int> = [2026, 2027]
    static let displaySummary = "2026–2027 public holidays"
    static let statusText = "Verified through 2027"

    static func supports(year: Int) -> Bool {
        supportedYears.contains(year)
    }

    static func validation(forYear year: Int) -> Validation {
        validation(requiredYears: [year])
    }

    static func validation(
        from start: Date,
        through end: Date,
        calendar: Calendar
    ) -> Validation {
        let lowerBound = min(start, end)
        let upperBound = max(start, end)
        let firstYear = calendar.component(.year, from: lowerBound)
        let finalYear = calendar.component(.year, from: upperBound)
        let years = firstYear <= finalYear ? Array(firstYear...finalYear) : []
        return validation(requiredYears: years)
    }

    static func validation(
        for range: ComplianceDateRange,
        calendar: Calendar
    ) -> Validation {
        validation(from: range.start, through: range.end, calendar: calendar)
    }

    private static var supportedYearsText: String {
        let years = supportedYears.sorted()
        guard let firstYear = years.first, let finalYear = years.last else {
            return "a supported holiday year"
        }

        if years == Array(firstYear...finalYear), firstYear != finalYear {
            return "\(firstYear)–\(finalYear)"
        }
        return years.map(String.init).joined(separator: ", ")
    }

    private static func validation(requiredYears: [Int]) -> Validation {
        let normalizedYears = Array(Set(requiredYears)).sorted()
        let unsupportedYears = normalizedYears.filter { !supportedYears.contains($0) }
        return Validation(requiredYears: normalizedYears, unsupportedYears: unsupportedYears)
    }
}
