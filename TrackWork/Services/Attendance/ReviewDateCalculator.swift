import Foundation

struct ReviewDateCalculator {
    struct Input {
        let range: ComplianceDateRange
        let calendar: Calendar
        let rule: ComplianceRule
        let attendanceDays: [AttendanceDay]
        let leaveRecords: [LeaveRecord]
        let publicHolidays: [PublicHoliday]
        let customExcludedDays: [CustomExcludedDay]
        let evaluationDate: Date
    }

    func datesNeedingReview(_ input: Input) -> [Date] {
        let eligibleDates = eligibleDates(input)
        let leaveDates = leaveDates(input, eligibleDates: eligibleDates)
        let excludedDates = excludedDates(
            input,
            eligibleDates: eligibleDates,
            leaveDates: leaveDates
        )
        let confirmedDates = confirmedDates(input)
        let today = input.calendar.startOfDay(for: input.evaluationDate)

        return eligibleDates
            .subtracting(leaveDates)
            .subtracting(excludedDates)
            .filter { $0 < today && !confirmedDates.contains($0) }
            .sorted()
    }

    private func eligibleDates(_ input: Input) -> Set<Date> {
        let holidayDates: Set<Date> = Set(
            input.publicHolidays.compactMap { holiday in
                guard holiday.jurisdictionId == input.rule.jurisdictionId,
                      input.range.contains(holiday.date, calendar: input.calendar) else {
                    return nil
                }
                return input.calendar.startOfDay(for: holiday.date)
            }
        )

        return BusinessDayCalculator().eligibleDates(
            from: input.range.start,
            through: input.range.end,
            calendar: input.calendar,
            selectedISOWeekdays: Set(input.rule.selectedISOWeekdays),
            publicHolidays: holidayDates
        )
    }

    private func leaveDates(_ input: Input, eligibleDates: Set<Date>) -> Set<Date> {
        Set(
            input.leaveRecords.compactMap { leaveRecord in
                guard leaveRecord.duration == .fullDay else {
                    return nil
                }
                let date = input.calendar.startOfDay(for: leaveRecord.date)
                return eligibleDates.contains(date) ? date : nil
            }
        )
    }

    private func excludedDates(
        _ input: Input,
        eligibleDates: Set<Date>,
        leaveDates: Set<Date>
    ) -> Set<Date> {
        Set(
            input.customExcludedDays.compactMap { excludedDay in
                let date = input.calendar.startOfDay(for: excludedDay.date)
                guard eligibleDates.contains(date), !leaveDates.contains(date) else {
                    return nil
                }
                return date
            }
        )
    }

    private func confirmedDates(_ input: Input) -> Set<Date> {
        Set(
            input.attendanceDays.compactMap { day in
                let date = input.calendar.startOfDay(for: day.date)
                guard let status = day.finalClassification, status != .unknown else {
                    return nil
                }
                return date
            }
        )
    }
}
