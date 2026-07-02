import Foundation

final class HolidayService {
    private let provider: HolidayProvider

    init(provider: HolidayProvider = LocalJSONHolidayProvider()) {
        self.provider = provider
    }

    func holidays(for country: Country, jurisdictionId: String, year: Int) throws -> [PublicHoliday] {
        try provider.holidays(for: country, jurisdictionId: jurisdictionId, year: year)
    }
}
