import Foundation

struct CompliancePeriodEvaluator {
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

    private let calculator = ComplianceCalculator()

    func evaluate(_ input: Input) -> ComplianceSummary {
        let attendanceDays = input.attendanceDays.filter {
            input.range.contains($0.date, calendar: input.calendar)
        }
        let leaveRecords = input.leaveRecords.filter {
            input.range.contains($0.date, calendar: input.calendar)
        }
        let publicHolidayDates: Set<Date> = Set(
            input.publicHolidays.compactMap { holiday in
                guard holiday.jurisdictionId == input.rule.jurisdictionId,
                      input.range.contains(holiday.date, calendar: input.calendar) else {
                    return nil
                }

                return input.calendar.startOfDay(for: holiday.date)
            }
        )
        let customExcludedDates: Set<Date> = Set(
            input.customExcludedDays.compactMap { excludedDay in
                guard input.range.contains(excludedDay.date, calendar: input.calendar) else {
                    return nil
                }

                return input.calendar.startOfDay(for: excludedDay.date)
            }
        )

        return calculator.calculate(
            ComplianceCalculator.Input(
                periodStart: input.range.start,
                periodEnd: input.range.end,
                calendar: input.calendar,
                selectedISOWeekdays: Set(input.rule.selectedISOWeekdays),
                publicHolidays: publicHolidayDates,
                leaveRecords: leaveRecords.compactMap(calculatorLeaveRecord),
                customExcludedDates: customExcludedDates,
                attendanceDays: attendanceDays.compactMap(calculatorAttendanceDay),
                requirement: calculatorRequirement(for: input.rule),
                minimumOfficeMinutes: input.rule.minimumOfficeMinutes,
                evaluationDate: input.evaluationDate
            )
        )
    }

    func calculatorRequirement(for rule: ComplianceRule) -> ComplianceCalculator.Requirement {
        switch rule.requirementType ?? .fixedMonthlyDays {
        case .fixedMonthlyDays:
            return .fixedMonthlyDays(
                baseRequiredDays: rule.fixedRequiredDays ?? 0,
                prorateForLeave: rule.prorateFixedTargetForLeave
            )
        case .percentageOfEligibleDays:
            return .percentageOfEligibleDays(rule.requiredPercentage ?? 0)
        }
    }

    private func calculatorLeaveRecord(_ record: LeaveRecord) -> ComplianceCalculator.LeaveRecord? {
        guard let leaveType = record.leaveType, let duration = record.duration else {
            return nil
        }

        return ComplianceCalculator.LeaveRecord(
            date: record.date,
            type: leaveType,
            duration: duration
        )
    }

    private func calculatorAttendanceDay(_ day: AttendanceDay) -> ComplianceCalculator.AttendanceDay? {
        guard let finalClassification = day.finalClassification else {
            return nil
        }

        return ComplianceCalculator.AttendanceDay(
            date: day.date,
            finalClassification: finalClassification,
            officeMinutes: day.officeMinutes
        )
    }
}
