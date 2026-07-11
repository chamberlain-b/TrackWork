import Foundation

enum CompliancePeriodPreset: String, CaseIterable, Identifiable {
    case currentMonth
    case last30Days
    case previousMonth
    case currentQuarter
    case previousQuarter
    case yearToDate
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .currentMonth:
            "Current month"
        case .last30Days:
            "Last 30 days"
        case .previousMonth:
            "Previous month"
        case .currentQuarter:
            "Current quarter"
        case .previousQuarter:
            "Previous quarter"
        case .yearToDate:
            "Year to date"
        case .custom:
            "Custom"
        }
    }

    func dateRange(
        calendar: Calendar,
        now: Date,
        customStart: Date,
        customEnd: Date
    ) -> ComplianceDateRange {
        let today = calendar.startOfDay(for: now)

        switch self {
        case .currentMonth:
            return ComplianceDateRange(
                start: calendar.complianceMonthStart(for: today),
                end: calendar.complianceMonthEnd(for: today),
                calendar: calendar
            )
        case .last30Days:
            let start = calendar.date(byAdding: .day, value: -29, to: today) ?? today
            return ComplianceDateRange(start: start, end: today, calendar: calendar)
        case .previousMonth:
            let currentMonthStart = calendar.complianceMonthStart(for: today)
            let start = calendar.date(byAdding: .month, value: -1, to: currentMonthStart)
                ?? currentMonthStart
            return ComplianceDateRange(
                start: start,
                end: calendar.complianceMonthEnd(for: start),
                calendar: calendar
            )
        case .currentQuarter:
            let start = calendar.complianceQuarterStart(for: today)
            return ComplianceDateRange(
                start: start,
                end: calendar.complianceQuarterEnd(for: start),
                calendar: calendar
            )
        case .previousQuarter:
            let currentQuarterStart = calendar.complianceQuarterStart(for: today)
            let start = calendar.date(byAdding: .month, value: -3, to: currentQuarterStart)
                ?? currentQuarterStart
            return ComplianceDateRange(
                start: start,
                end: calendar.complianceQuarterEnd(for: start),
                calendar: calendar
            )
        case .yearToDate:
            return ComplianceDateRange(
                start: calendar.complianceYearStart(for: today),
                end: today,
                calendar: calendar
            )
        case .custom:
            return ComplianceDateRange(start: customStart, end: customEnd, calendar: calendar)
        }
    }
}

struct ComplianceDateRange: Equatable {
    let start: Date
    let end: Date

    init(start: Date, end: Date, calendar: Calendar) {
        let normalizedStart = calendar.startOfDay(for: start)
        let normalizedEnd = calendar.startOfDay(for: end)

        if normalizedStart <= normalizedEnd {
            self.start = normalizedStart
            self.end = normalizedEnd
        } else {
            self.start = normalizedEnd
            self.end = normalizedStart
        }
    }

    func contains(_ date: Date, calendar: Calendar) -> Bool {
        let normalizedDate = calendar.startOfDay(for: date)
        return normalizedDate >= start && normalizedDate <= end
    }
}

extension Calendar {
    func complianceMonthStart(for date: Date) -> Date {
        dateInterval(of: .month, for: date)?.start ?? startOfDay(for: date)
    }

    func complianceMonthEnd(for date: Date) -> Date {
        guard let monthInterval = dateInterval(of: .month, for: date),
              let finalDate = self.date(byAdding: .day, value: -1, to: monthInterval.end) else {
            return startOfDay(for: date)
        }

        return startOfDay(for: finalDate)
    }

    func complianceQuarterStart(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        guard let year = components.year, let month = components.month else {
            return startOfDay(for: date)
        }

        let quarterStartMonth = ((month - 1) / 3) * 3 + 1
        return self.date(from: DateComponents(year: year, month: quarterStartMonth, day: 1))
            ?? startOfDay(for: date)
    }

    func complianceQuarterEnd(for date: Date) -> Date {
        let start = complianceQuarterStart(for: date)
        guard let nextQuarter = self.date(byAdding: .month, value: 3, to: start),
              let end = self.date(byAdding: .day, value: -1, to: nextQuarter) else {
            return start
        }

        return startOfDay(for: end)
    }

    func complianceYearStart(for date: Date) -> Date {
        dateInterval(of: .year, for: date)?.start ?? startOfDay(for: date)
    }

    func complianceYearEnd(for date: Date) -> Date {
        guard let interval = dateInterval(of: .year, for: date),
              let end = self.date(byAdding: .day, value: -1, to: interval.end) else {
            return startOfDay(for: date)
        }

        return startOfDay(for: end)
    }
}
