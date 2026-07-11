import Foundation

enum ActiveJurisdictionHolidayResolver {
    static func holidays(
        from publicHolidays: [PublicHoliday],
        jurisdictionId: String
    ) -> [PublicHoliday] {
        publicHolidays.filter { $0.jurisdictionId == jurisdictionId }
    }

    static func holiday(
        on date: Date,
        from publicHolidays: [PublicHoliday],
        jurisdictionId: String,
        calendar: Calendar
    ) -> PublicHoliday? {
        holidays(from: publicHolidays, jurisdictionId: jurisdictionId)
            .first { calendar.isDate($0.date, inSameDayAs: date) }
    }
}
