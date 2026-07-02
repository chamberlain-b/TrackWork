import Foundation

struct BusinessDayCalculator {
    func eligibleDates(
        from periodStart: Date,
        through periodEnd: Date,
        calendar: Calendar,
        selectedISOWeekdays: Set<Int>,
        publicHolidays: Set<Date>
    ) -> Set<Date> {
        guard periodStart <= periodEnd else {
            return []
        }

        let normalizedHolidays = Set(publicHolidays.map { calendar.startOfDay(for: $0) })
        var eligibleDates: Set<Date> = []
        var currentDate = calendar.startOfDay(for: periodStart)
        let finalDate = calendar.startOfDay(for: periodEnd)

        while currentDate <= finalDate {
            if selectedISOWeekdays.contains(isoWeekday(for: currentDate, calendar: calendar)),
               !normalizedHolidays.contains(currentDate) {
                eligibleDates.insert(currentDate)
            }

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }

        return eligibleDates
    }

    private func isoWeekday(for date: Date, calendar: Calendar) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 ? 7 : weekday - 1
    }
}

struct ComplianceSummary: Equatable {
    let baseEligibleDays: Int
    let adjustedEligibleDays: Int
    let requiredOfficeDays: Int
    let completedOfficeDays: Int
    let reviewRequiredDays: Int
}

struct ComplianceCalculator {
    struct Input {
        let periodStart: Date
        let periodEnd: Date
        let calendar: Calendar
        let selectedISOWeekdays: Set<Int>
        let publicHolidays: Set<Date>
        let leaveRecords: [LeaveRecord]
        let attendanceDays: [AttendanceDay]
        let requirement: Requirement
    }

    struct LeaveRecord {
        let date: Date
        let type: LeaveType
        let duration: LeaveDuration
    }

    struct AttendanceDay {
        let date: Date
        let finalClassification: AttendanceClassification
        let officeMinutes: Int
    }

    enum Requirement {
        case percentageOfEligibleDays(Double)
        case fixedMonthlyDays(baseRequiredDays: Int, prorateForLeave: Bool)
    }

    typealias Summary = ComplianceSummary

    private let officeDayMinimumMinutes = 180

    func calculate(_ input: Input) -> Summary {
        let businessDayCalculator = BusinessDayCalculator()
        let eligibleDates = businessDayCalculator.eligibleDates(
            from: input.periodStart,
            through: input.periodEnd,
            calendar: input.calendar,
            selectedISOWeekdays: input.selectedISOWeekdays,
            publicHolidays: input.publicHolidays
        )

        let baseEligibleDays = eligibleDates.count
        let leaveAdjustedDates = eligibleLeaveDates(
            from: input.leaveRecords,
            eligibleDates: eligibleDates,
            calendar: input.calendar
        )
        let adjustedEligibleDays = max(0, baseEligibleDays - leaveAdjustedDates.count)
        let requiredOfficeDays = requiredOfficeDays(
            for: input.requirement,
            baseEligibleDays: baseEligibleDays,
            adjustedEligibleDays: adjustedEligibleDays
        )
        let completedOfficeDays = completedOfficeDays(
            from: input.attendanceDays,
            calendar: input.calendar
        )
        let reviewRequiredDays = reviewRequiredDays(from: input.attendanceDays)

        return Summary(
            baseEligibleDays: baseEligibleDays,
            adjustedEligibleDays: adjustedEligibleDays,
            requiredOfficeDays: requiredOfficeDays,
            completedOfficeDays: completedOfficeDays,
            reviewRequiredDays: reviewRequiredDays
        )
    }

    private func eligibleLeaveDates(
        from leaveRecords: [LeaveRecord],
        eligibleDates: Set<Date>,
        calendar: Calendar
    ) -> Set<Date> {
        Set(
            leaveRecords.compactMap { leaveRecord in
                guard leaveRecord.duration == .fullDay else {
                    return nil
                }

                switch leaveRecord.type {
                case .annualLeave, .sickLeave:
                    let normalizedDate = calendar.startOfDay(for: leaveRecord.date)
                    return eligibleDates.contains(normalizedDate) ? normalizedDate : nil
                }
            }
        )
    }

    private func requiredOfficeDays(
        for requirement: Requirement,
        baseEligibleDays: Int,
        adjustedEligibleDays: Int
    ) -> Int {
        switch requirement {
        case let .percentageOfEligibleDays(percentage):
            return Int(ceil(Double(adjustedEligibleDays) * percentage))
        case let .fixedMonthlyDays(baseRequiredDays, prorateForLeave):
            guard prorateForLeave, baseEligibleDays > 0 else {
                return baseRequiredDays
            }

            let proratedRequirement = Double(baseRequiredDays) * Double(adjustedEligibleDays) / Double(baseEligibleDays)
            return Int(ceil(proratedRequirement))
        }
    }

    private func completedOfficeDays(
        from attendanceDays: [AttendanceDay],
        calendar: Calendar
    ) -> Int {
        Set(
            attendanceDays.compactMap { attendanceDay in
                switch attendanceDay.finalClassification {
                case .office:
                    return calendar.startOfDay(for: attendanceDay.date)
                case .mixed where attendanceDay.officeMinutes >= officeDayMinimumMinutes:
                    return calendar.startOfDay(for: attendanceDay.date)
                default:
                    return nil
                }
            }
        ).count
    }

    private func reviewRequiredDays(from attendanceDays: [AttendanceDay]) -> Int {
        attendanceDays.filter { $0.finalClassification == .unknown }.count
    }
}
