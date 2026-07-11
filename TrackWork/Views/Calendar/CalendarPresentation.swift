import SwiftUI

extension LeaveType {
    var classification: AttendanceClassification {
        switch self {
        case .annualLeave:
            .annualLeave
        case .sickLeave:
            .sickLeave
        }
    }

    var calendarBadgeText: String {
        switch self {
        case .annualLeave:
            "AL"
        case .sickLeave:
            "SL"
        }
    }
}

extension AttendanceClassification {
    var leaveType: LeaveType? {
        switch self {
        case .annualLeave:
            .annualLeave
        case .sickLeave:
            .sickLeave
        case .office, .home, .mixed, .publicHoliday, .weekend, .nonWorkingDay, .unknown:
            nil
        }
    }

    var calendarBadgeText: String {
        switch self {
        case .office:
            "O"
        case .home:
            "H"
        case .mixed:
            "M"
        case .annualLeave:
            "AL"
        case .sickLeave:
            "SL"
        case .publicHoliday:
            "PH"
        case .weekend, .nonWorkingDay, .unknown:
            "?"
        }
    }

    var calendarBadgeBackgroundColor: Color {
        switch self {
        case .office:
            Color.ds.officeDay.opacity(0.18)
        case .home:
            Color.ds.homeDay.opacity(0.18)
        case .mixed:
            Color.ds.info.opacity(0.18)
        case .annualLeave, .sickLeave:
            Color.ds.leaveDay.opacity(0.18)
        case .publicHoliday:
            Color.ds.publicHoliday.opacity(0.18)
        case .weekend, .nonWorkingDay, .unknown:
            Color.ds.surfaceSecondary
        }
    }

    var calendarBadgeForegroundColor: Color {
        switch self {
        case .office:
            Color.ds.officeDay
        case .home:
            Color.ds.homeDay
        case .mixed:
            Color.ds.info
        case .annualLeave, .sickLeave:
            Color.ds.leaveDay
        case .publicHoliday:
            Color.ds.publicHoliday
        case .weekend, .nonWorkingDay, .unknown:
            Color.ds.textTertiary
        }
    }
}

extension Calendar {
    static var workTrackCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = .autoupdatingCurrent
        calendar.timeZone = .autoupdatingCurrent
        calendar.firstWeekday = 2
        return calendar
    }

    func calendarViewMonthStart(for date: Date) -> Date {
        dateInterval(of: .month, for: date)?.start ?? startOfDay(for: date)
    }

    func datesInMonth(containing date: Date) -> [Date] {
        guard let monthInterval = dateInterval(of: .month, for: date),
              let dayRange = range(of: .day, in: .month, for: monthInterval.start)
        else {
            return []
        }

        return dayRange.compactMap { day in
            self.date(byAdding: .day, value: day - 1, to: monthInterval.start)
        }
    }

    func mondayBasedWeekdayIndex(for date: Date) -> Int {
        let weekday = component(.weekday, from: date)
        return (weekday + 5) % 7
    }

    func isoWeekday(for date: Date) -> Int {
        let weekday = component(.weekday, from: date)
        return weekday == 1 ? 7 : weekday - 1
    }

    func calendarDayAccessibilityIdentifier(for date: Date) -> String {
        let components = dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "calendar.day.%04d-%02d-%02d", year, month, day)
    }
}
