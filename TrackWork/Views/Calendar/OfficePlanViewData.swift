import Foundation

extension OfficePlanView {
    var range: ComplianceDateRange {
        ComplianceDateRange(
            start: calendar.complianceMonthStart(for: displayedMonthValue),
            end: calendar.complianceMonthEnd(for: displayedMonthValue),
            calendar: calendar
        )
    }

    var activeRule: ComplianceRule {
        ruleResolver.rule(for: range.end, from: complianceRules) ?? ComplianceRule()
    }

    var summary: ComplianceSummary {
        evaluator.evaluate(
            CompliancePeriodEvaluator.Input(
                range: range,
                calendar: calendar,
                rule: activeRule,
                attendanceDays: attendanceDays,
                leaveRecords: leaveRecords,
                publicHolidays: publicHolidays,
                customExcludedDays: customExcludedDays,
                evaluationDate: calendar.startOfDay(for: referenceDate)
            )
        )
    }

    var candidateDates: [Date] {
        candidateDateCalculator.candidateDates(
            OfficePlanCandidateDateCalculator.Input(
                range: range,
                calendar: calendar,
                rule: activeRule,
                attendanceDays: attendanceDays,
                leaveRecords: leaveRecords,
                publicHolidays: publicHolidays,
                customExcludedDays: customExcludedDays,
                evaluationDate: referenceDate
            )
        )
    }

    var candidateDateSet: Set<Date> {
        Set(candidateDates)
    }

    var selectedDates: Set<Date> {
        Set(
            plannedOfficeDays.compactMap { plan in
                let date = calendar.startOfDay(for: plan.date)
                return range.contains(date, calendar: calendar) ? date : nil
            }
        )
    }

    var validSelectedDates: Set<Date> {
        selectedDates.intersection(candidateDateSet)
    }

    var invalidSelectedDates: Set<Date> {
        selectedDates.subtracting(candidateDateSet)
    }

    var invalidSelectedPlans: [PlannedOfficeDay] {
        plannedOfficeDays.filter { plan in
            let date = calendar.startOfDay(for: plan.date)
            return range.contains(date, calendar: calendar)
                && invalidSelectedDates.contains(date)
        }
    }

    var unavailableRemovalNeedsConfirmation: Bool {
        invalidSelectedPlans.count > 1
            || invalidSelectedPlans.contains { $0.note != nil }
    }

    var preferredISOWeekdays: Set<Int> {
        Set(activeRule.preferredOfficeISOWeekdays)
    }

    var remainingOfficeDays: Int {
        summary.officeDaysNeeded
    }

    var additionalPlansNeeded: Int {
        max(0, remainingOfficeDays - plannedCandidateDays)
    }

    var plannedCandidateDays: Int {
        validSelectedDates.count
    }

    var unselectedCandidateDates: Set<Date> {
        candidateDateSet.subtracting(validSelectedDates)
    }

    var holidayDates: Set<Date> {
        Set(
            publicHolidays.compactMap { holiday -> Date? in
                guard holiday.jurisdictionId == activeRule.jurisdictionId,
                      range.contains(holiday.date, calendar: calendar) else {
                    return nil
                }
                return calendar.startOfDay(for: holiday.date)
            }
        )
    }

    var eligibleDatesBeforeLeave: Set<Date> {
        BusinessDayCalculator().eligibleDates(
            from: range.start,
            through: range.end,
            calendar: calendar,
            selectedISOWeekdays: Set(activeRule.selectedISOWeekdays),
            publicHolidays: holidayDates
        )
    }

    var leaveDates: Set<Date> {
        Set(
            leaveRecords.compactMap { record -> Date? in
                guard record.leaveType != nil,
                      record.duration == .fullDay else {
                    return nil
                }
                let date = calendar.startOfDay(for: record.date)
                return eligibleDatesBeforeLeave.contains(date) ? date : nil
            }
        )
    }

    var exclusionDates: Set<Date> {
        Set(
            customExcludedDays.compactMap { excludedDay -> Date? in
                guard range.contains(excludedDay.date, calendar: calendar) else {
                    return nil
                }
                return calendar.startOfDay(for: excludedDay.date)
            }
        )
    }

    var adjustedEligibleDates: Set<Date> {
        eligibleDatesBeforeLeave
            .subtracting(leaveDates)
            .subtracting(exclusionDates)
    }

    var completedOfficeDates: Set<Date> {
        let evaluationDate = calendar.startOfDay(for: referenceDate)
        return Set(
            attendanceDays.compactMap { day -> Date? in
                let date = calendar.startOfDay(for: day.date)
                guard date <= evaluationDate,
                      adjustedEligibleDates.contains(date) else {
                    return nil
                }

                switch day.finalClassification {
                case .office:
                    return date
                case .mixed where day.officeMinutes >= activeRule.minimumOfficeMinutes:
                    return date
                default:
                    return nil
                }
            }
        )
    }

    var calendarWeeks: [OfficePlanWeek] {
        OfficePlanWeekBuilder().weeks(in: range, calendar: calendar)
    }

    var recommendedDates: [Date] {
        let additions = suggestionService.balancedSuggestedDates(
            from: candidateDates,
            excluding: validSelectedDates,
            count: additionalPlansNeeded,
            preferredISOWeekdays: preferredISOWeekdays,
            calendar: calendar
        )
        return Array(validSelectedDates.union(additions)).sorted()
    }

    var recommendedCountsByWeek: [Date: Int] {
        Dictionary(
            grouping: recommendedDates,
            by: weekStart(for:)
        )
        .mapValues(\.count)
    }
}
