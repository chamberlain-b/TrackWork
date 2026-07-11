import Foundation

enum ComplianceTrendGranularity: String, CaseIterable, Identifiable {
    case monthly
    case quarterly
    case yearly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .monthly:
            "Monthly"
        case .quarterly:
            "Quarterly"
        case .yearly:
            "Yearly"
        }
    }
}

struct ComplianceTrendPoint: Identifiable, Equatable {
    var id: Date { range.start }

    let range: ComplianceDateRange
    let label: String
    let completedOfficeDays: Int
    let requiredOfficeDays: Int
    let hasRecordedData: Bool
}

struct ComplianceTrendCalculator {
    private let evaluator = CompliancePeriodEvaluator()

    func points(
        granularity: ComplianceTrendGranularity,
        endingAt referenceDate: Date,
        bucketCount: Int = 6,
        calendar: Calendar,
        rule: ComplianceRule,
        attendanceDays: [AttendanceDay],
        leaveRecords: [LeaveRecord],
        publicHolidays: [PublicHoliday],
        customExcludedDays: [CustomExcludedDay]
    ) -> [ComplianceTrendPoint] {
        guard bucketCount > 0 else {
            return []
        }

        let currentRange = range(containing: referenceDate, granularity: granularity, calendar: calendar)

        return (0..<bucketCount).reversed().compactMap { offset in
            guard let range = offsetRange(
                currentRange,
                by: -offset,
                granularity: granularity,
                calendar: calendar
            ) else {
                return nil
            }

            let summary = evaluator.evaluate(
                CompliancePeriodEvaluator.Input(
                    range: range,
                    calendar: calendar,
                    rule: rule,
                    attendanceDays: attendanceDays,
                    leaveRecords: leaveRecords,
                    publicHolidays: publicHolidays,
                    customExcludedDays: customExcludedDays,
                    evaluationDate: referenceDate
                )
            )

            return ComplianceTrendPoint(
                range: range,
                label: label(for: range.start, granularity: granularity, calendar: calendar),
                completedOfficeDays: summary.completedOfficeDays,
                requiredOfficeDays: summary.requiredOfficeDays,
                hasRecordedData: hasRecordedData(
                    in: range,
                    calendar: calendar,
                    attendanceDays: attendanceDays,
                    leaveRecords: leaveRecords,
                    customExcludedDays: customExcludedDays
                )
            )
        }
    }

    private func range(
        containing date: Date,
        granularity: ComplianceTrendGranularity,
        calendar: Calendar
    ) -> ComplianceDateRange {
        switch granularity {
        case .monthly:
            return ComplianceDateRange(
                start: calendar.complianceMonthStart(for: date),
                end: calendar.complianceMonthEnd(for: date),
                calendar: calendar
            )
        case .quarterly:
            return ComplianceDateRange(
                start: calendar.complianceQuarterStart(for: date),
                end: calendar.complianceQuarterEnd(for: date),
                calendar: calendar
            )
        case .yearly:
            return ComplianceDateRange(
                start: calendar.complianceYearStart(for: date),
                end: calendar.complianceYearEnd(for: date),
                calendar: calendar
            )
        }
    }

    private func offsetRange(
        _ range: ComplianceDateRange,
        by offset: Int,
        granularity: ComplianceTrendGranularity,
        calendar: Calendar
    ) -> ComplianceDateRange? {
        let component: Calendar.Component
        let value: Int

        switch granularity {
        case .monthly:
            component = .month
            value = offset
        case .quarterly:
            component = .month
            value = offset * 3
        case .yearly:
            component = .year
            value = offset
        }

        guard let shiftedStart = calendar.date(byAdding: component, value: value, to: range.start) else {
            return nil
        }

        return self.range(containing: shiftedStart, granularity: granularity, calendar: calendar)
    }

    private func label(
        for date: Date,
        granularity: ComplianceTrendGranularity,
        calendar: Calendar
    ) -> String {
        switch granularity {
        case .monthly:
            return date.formatted(.dateTime.month(.abbreviated).year(.twoDigits))
        case .quarterly:
            let quarter = ((calendar.component(.month, from: date) - 1) / 3) + 1
            let year = calendar.component(.year, from: date) % 100
            return "Q\(quarter) \(String(format: "%02d", year))"
        case .yearly:
            return date.formatted(.dateTime.year())
        }
    }

    private func hasRecordedData(
        in range: ComplianceDateRange,
        calendar: Calendar,
        attendanceDays: [AttendanceDay],
        leaveRecords: [LeaveRecord],
        customExcludedDays: [CustomExcludedDay]
    ) -> Bool {
        attendanceDays.contains { range.contains($0.date, calendar: calendar) }
            || leaveRecords.contains { range.contains($0.date, calendar: calendar) }
            || customExcludedDays.contains { range.contains($0.date, calendar: calendar) }
    }
}
