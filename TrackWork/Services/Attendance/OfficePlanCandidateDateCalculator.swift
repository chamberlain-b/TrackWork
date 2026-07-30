import Foundation

struct OfficePlanCandidateDateCalculator {
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

    func candidateDates(_ input: Input) -> [Date] {
        let evaluationDate = input.calendar.startOfDay(for: input.evaluationDate)
        let holidayDateSet = holidayDates(input)
        let eligibleDatesBeforeLeave = BusinessDayCalculator().eligibleDates(
            from: input.range.start,
            through: input.range.end,
            calendar: input.calendar,
            selectedISOWeekdays: Set(input.rule.selectedISOWeekdays),
            publicHolidays: holidayDateSet
        )
        let leaveDateSet = leaveDates(input, eligibleDates: eligibleDatesBeforeLeave)
        let exclusionDateSet = exclusionDates(input)
        let adjustedEligibleDates = eligibleDatesBeforeLeave
            .subtracting(leaveDateSet)
            .subtracting(exclusionDateSet)
        let completedOfficeDateSet = completedOfficeDates(
            input,
            eligibleDates: adjustedEligibleDates,
            evaluationDate: evaluationDate
        )

        return adjustedEligibleDates
            .subtracting(completedOfficeDateSet)
            .filter { $0 >= evaluationDate }
            .sorted()
    }

    private func holidayDates(_ input: Input) -> Set<Date> {
        Set(
            input.publicHolidays.compactMap { holiday -> Date? in
                guard holiday.jurisdictionId == input.rule.jurisdictionId,
                      input.range.contains(holiday.date, calendar: input.calendar) else {
                    return nil
                }
                return input.calendar.startOfDay(for: holiday.date)
            }
        )
    }

    private func leaveDates(
        _ input: Input,
        eligibleDates: Set<Date>
    ) -> Set<Date> {
        Set(
            input.leaveRecords.compactMap { record -> Date? in
                guard record.leaveType != nil,
                      record.duration == .fullDay else {
                    return nil
                }
                let date = input.calendar.startOfDay(for: record.date)
                return eligibleDates.contains(date) ? date : nil
            }
        )
    }

    private func exclusionDates(_ input: Input) -> Set<Date> {
        Set(
            input.customExcludedDays.compactMap { excludedDay -> Date? in
                let date = input.calendar.startOfDay(for: excludedDay.date)
                return input.range.contains(date, calendar: input.calendar) ? date : nil
            }
        )
    }

    private func completedOfficeDates(
        _ input: Input,
        eligibleDates: Set<Date>,
        evaluationDate: Date
    ) -> Set<Date> {
        Set(
            input.attendanceDays.compactMap { day -> Date? in
                let date = input.calendar.startOfDay(for: day.date)
                guard date <= evaluationDate,
                      eligibleDates.contains(date) else {
                    return nil
                }

                switch day.finalClassification {
                case .office:
                    return date
                case .mixed where day.officeMinutes >= input.rule.minimumOfficeMinutes:
                    return date
                default:
                    return nil
                }
            }
        )
    }
}
