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
    let eligibleDaysToDate: Int
    let customExcludedDays: Int
    let requiredOfficeDays: Int
    let completedOfficeDays: Int
    let reviewRequiredDays: Int

    var officeDaysNeeded: Int {
        max(0, requiredOfficeDays - completedOfficeDays)
    }

    var officeShareToDate: Double? {
        guard eligibleDaysToDate > 0 else {
            return nil
        }

        return Double(completedOfficeDays) / Double(eligibleDaysToDate)
    }
}

struct ComplianceCalculator {
    struct Input {
        let periodStart: Date
        let periodEnd: Date
        let calendar: Calendar
        let selectedISOWeekdays: Set<Int>
        let publicHolidays: Set<Date>
        let leaveRecords: [LeaveRecord]
        let customExcludedDates: Set<Date>
        let attendanceDays: [AttendanceDay]
        let requirement: Requirement
        let minimumOfficeMinutes: Int
        let evaluationDate: Date?

        init(
            periodStart: Date,
            periodEnd: Date,
            calendar: Calendar,
            selectedISOWeekdays: Set<Int>,
            publicHolidays: Set<Date>,
            leaveRecords: [LeaveRecord],
            customExcludedDates: Set<Date> = [],
            attendanceDays: [AttendanceDay],
            requirement: Requirement,
            minimumOfficeMinutes: Int = 180,
            evaluationDate: Date? = nil
        ) {
            self.periodStart = periodStart
            self.periodEnd = periodEnd
            self.calendar = calendar
            self.selectedISOWeekdays = selectedISOWeekdays
            self.publicHolidays = publicHolidays
            self.leaveRecords = leaveRecords
            self.customExcludedDates = customExcludedDates
            self.attendanceDays = attendanceDays
            self.requirement = requirement
            self.minimumOfficeMinutes = minimumOfficeMinutes
            self.evaluationDate = evaluationDate
        }
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
        let eligibleCustomExcludedDates = Set(
            input.customExcludedDates
                .map { input.calendar.startOfDay(for: $0) }
                .filter(eligibleDates.contains)
        )
        let effectiveCustomExcludedDates = eligibleCustomExcludedDates.subtracting(leaveAdjustedDates)
        let adjustedEligibleDates = eligibleDates
            .subtracting(leaveAdjustedDates)
            .subtracting(effectiveCustomExcludedDates)
        let adjustedEligibleDays = adjustedEligibleDates.count
        let eligibleDaysToDate = eligibleDaysToDate(
            in: adjustedEligibleDates,
            evaluationDate: input.evaluationDate,
            calendar: input.calendar
        )
        let requiredOfficeDays = requiredOfficeDays(
            for: input.requirement,
            baseEligibleDays: baseEligibleDays,
            adjustedEligibleDays: adjustedEligibleDays
        )
        let completedOfficeDays = completedOfficeDays(
            from: input.attendanceDays,
            eligibleDates: adjustedEligibleDates,
            minimumOfficeMinutes: input.minimumOfficeMinutes,
            evaluationDate: input.evaluationDate,
            calendar: input.calendar
        )
        let reviewRequiredDays = reviewRequiredDays(
            from: input.attendanceDays,
            eligibleDates: adjustedEligibleDates,
            evaluationDate: input.evaluationDate,
            calendar: input.calendar
        )

        return Summary(
            baseEligibleDays: baseEligibleDays,
            adjustedEligibleDays: adjustedEligibleDays,
            eligibleDaysToDate: eligibleDaysToDate,
            customExcludedDays: effectiveCustomExcludedDates.count,
            requiredOfficeDays: requiredOfficeDays,
            completedOfficeDays: completedOfficeDays,
            reviewRequiredDays: reviewRequiredDays
        )
    }

    private func eligibleDaysToDate(
        in eligibleDates: Set<Date>,
        evaluationDate: Date?,
        calendar: Calendar
    ) -> Int {
        guard let evaluationDate else {
            return eligibleDates.count
        }

        let cutoff = calendar.startOfDay(for: evaluationDate)
        return eligibleDates.filter { $0 <= cutoff }.count
    }

    private func eligibleLeaveDates(
        from leaveRecords: [LeaveRecord],
        eligibleDates: Set<Date>,
        calendar: Calendar
    ) -> Set<Date> {
        return Set<Date>(
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
        eligibleDates: Set<Date>,
        minimumOfficeMinutes: Int,
        evaluationDate: Date?,
        calendar: Calendar
    ) -> Int {
        let normalizedEvaluationDate = evaluationDate.map { calendar.startOfDay(for: $0) }

        return Set<Date>(
            attendanceDays.compactMap { attendanceDay in
                let normalizedDate = calendar.startOfDay(for: attendanceDay.date)
                guard eligibleDates.contains(normalizedDate),
                      normalizedEvaluationDate.map({ normalizedDate <= $0 }) ?? true else {
                    return nil
                }

                let treatment = ComplianceTreatmentResolver.resolve(
                    classification: attendanceDay.finalClassification,
                    officeMinutes: attendanceDay.officeMinutes,
                    minimumOfficeMinutes: minimumOfficeMinutes
                )
                return treatment == .countsAsOffice ? normalizedDate : nil
            }
        ).count
    }

    private func reviewRequiredDays(
        from attendanceDays: [AttendanceDay],
        eligibleDates: Set<Date>,
        evaluationDate: Date?,
        calendar: Calendar
    ) -> Int {
        guard let evaluationDate else {
            return Set<Date>(
                attendanceDays.compactMap { attendanceDay in
                    guard attendanceDay.finalClassification == .unknown else {
                        return nil
                    }

                    let normalizedDate = calendar.startOfDay(for: attendanceDay.date)
                    return eligibleDates.contains(normalizedDate) ? normalizedDate : nil
                }
            ).count
        }

        let normalizedEvaluationDate = calendar.startOfDay(for: evaluationDate)
        let reviewableDates = Set(eligibleDates.filter { $0 < normalizedEvaluationDate })
        let resolvedDates = Set<Date>(
            attendanceDays.compactMap { attendanceDay in
                guard attendanceDay.finalClassification != .unknown else {
                    return nil
                }

                let normalizedDate = calendar.startOfDay(for: attendanceDay.date)
                return reviewableDates.contains(normalizedDate) ? normalizedDate : nil
            }
        )

        return reviewableDates.subtracting(resolvedDates).count
    }
}
