import Foundation

struct OfficePlanViewDataSnapshot {
    let range: ComplianceDateRange
    let activeRule: ComplianceRule
    let summary: ComplianceSummary
    let candidateDates: [Date]
    let candidateDateSet: Set<Date>
    let selectedDates: Set<Date>
    let validSelectedDates: Set<Date>
    let invalidSelectedDates: Set<Date>
    let invalidSelectedPlans: [PlannedOfficeDay]
    let unavailableRemovalNeedsConfirmation: Bool
    let preferredISOWeekdays: Set<Int>
    let remainingOfficeDays: Int
    let additionalPlansNeeded: Int
    let plannedCandidateDays: Int
    let unselectedCandidateDates: Set<Date>
    let holidayDates: Set<Date>
    let eligibleDatesBeforeLeave: Set<Date>
    let leaveDates: Set<Date>
    let exclusionDates: Set<Date>
    let adjustedEligibleDates: Set<Date>
    let completedOfficeDates: Set<Date>
    let calendarWeeks: [OfficePlanWeek]
    let recommendedDates: [Date]
    let recommendedCountsByWeek: [Date: Int]
}

extension OfficePlanView {
    var planData: OfficePlanViewDataSnapshot {
        let range = ComplianceDateRange(
            start: calendar.complianceMonthStart(for: displayedMonthValue),
            end: calendar.complianceMonthEnd(for: displayedMonthValue),
            calendar: calendar
        )
        let activeRule = ruleResolver.rule(for: range.end, from: complianceRules) ?? ComplianceRule()
        let summary = evaluator.evaluate(
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
        let candidateDates = candidateDateCalculator.candidateDates(
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
        let candidateDateSet = Set(candidateDates)
        let selectedDates = Set(
            plannedOfficeDays.compactMap { plan in
                let date = calendar.startOfDay(for: plan.date)
                return range.contains(date, calendar: calendar) ? date : nil
            }
        )
        let validSelectedDates = selectedDates.intersection(candidateDateSet)
        let invalidSelectedDates = selectedDates.subtracting(candidateDateSet)
        let invalidSelectedPlans = plannedOfficeDays.filter { plan in
            let date = calendar.startOfDay(for: plan.date)
            return range.contains(date, calendar: calendar)
                && invalidSelectedDates.contains(date)
        }
        let preferredISOWeekdays = Set(activeRule.preferredOfficeISOWeekdays)
        let remainingOfficeDays = summary.officeDaysNeeded
        let plannedCandidateDays = validSelectedDates.count
        let additionalPlansNeeded = max(0, remainingOfficeDays - plannedCandidateDays)
        let holidayDates = Set(
            publicHolidays.compactMap { holiday -> Date? in
                guard holiday.jurisdictionId == activeRule.jurisdictionId,
                      range.contains(holiday.date, calendar: calendar) else {
                    return nil
                }
                return calendar.startOfDay(for: holiday.date)
            }
        )
        let eligibleDatesBeforeLeave = BusinessDayCalculator().eligibleDates(
            from: range.start,
            through: range.end,
            calendar: calendar,
            selectedISOWeekdays: Set(activeRule.selectedISOWeekdays),
            publicHolidays: holidayDates
        )
        let leaveDates = Set(
            leaveRecords.compactMap { record -> Date? in
                guard record.leaveType != nil,
                      record.duration == .fullDay else {
                    return nil
                }
                let date = calendar.startOfDay(for: record.date)
                return eligibleDatesBeforeLeave.contains(date) ? date : nil
            }
        )
        let exclusionDates = Set(
            customExcludedDays.compactMap { excludedDay -> Date? in
                guard range.contains(excludedDay.date, calendar: calendar) else {
                    return nil
                }
                return calendar.startOfDay(for: excludedDay.date)
            }
        )
        let adjustedEligibleDates = eligibleDatesBeforeLeave
            .subtracting(leaveDates)
            .subtracting(exclusionDates)
        let evaluationDate = calendar.startOfDay(for: referenceDate)
        let completedOfficeDates = Set(
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
        let calendarWeeks = OfficePlanWeekBuilder().weeks(in: range, calendar: calendar)
        let recommendedAdditions = suggestionService.balancedSuggestedDates(
            from: candidateDates,
            excluding: validSelectedDates,
            count: additionalPlansNeeded,
            preferredISOWeekdays: preferredISOWeekdays,
            calendar: calendar
        )
        let recommendedDates = Array(validSelectedDates.union(recommendedAdditions)).sorted()
        let recommendedCountsByWeek = Dictionary(
            grouping: recommendedDates,
            by: weekStart(for:)
        )
        .mapValues(\.count)

        return OfficePlanViewDataSnapshot(
            range: range,
            activeRule: activeRule,
            summary: summary,
            candidateDates: candidateDates,
            candidateDateSet: candidateDateSet,
            selectedDates: selectedDates,
            validSelectedDates: validSelectedDates,
            invalidSelectedDates: invalidSelectedDates,
            invalidSelectedPlans: invalidSelectedPlans,
            unavailableRemovalNeedsConfirmation: invalidSelectedPlans.count > 1
                || invalidSelectedPlans.contains { $0.note != nil },
            preferredISOWeekdays: preferredISOWeekdays,
            remainingOfficeDays: remainingOfficeDays,
            additionalPlansNeeded: additionalPlansNeeded,
            plannedCandidateDays: plannedCandidateDays,
            unselectedCandidateDates: candidateDateSet.subtracting(validSelectedDates),
            holidayDates: holidayDates,
            eligibleDatesBeforeLeave: eligibleDatesBeforeLeave,
            leaveDates: leaveDates,
            exclusionDates: exclusionDates,
            adjustedEligibleDates: adjustedEligibleDates,
            completedOfficeDates: completedOfficeDates,
            calendarWeeks: calendarWeeks,
            recommendedDates: recommendedDates,
            recommendedCountsByWeek: recommendedCountsByWeek
        )
    }

    var range: ComplianceDateRange { planData.range }
    var activeRule: ComplianceRule { planData.activeRule }
    var summary: ComplianceSummary { planData.summary }
    var candidateDates: [Date] { planData.candidateDates }
    var candidateDateSet: Set<Date> { planData.candidateDateSet }
    var selectedDates: Set<Date> { planData.selectedDates }
    var validSelectedDates: Set<Date> { planData.validSelectedDates }
    var invalidSelectedDates: Set<Date> { planData.invalidSelectedDates }
    var invalidSelectedPlans: [PlannedOfficeDay] { planData.invalidSelectedPlans }
    var unavailableRemovalNeedsConfirmation: Bool { planData.unavailableRemovalNeedsConfirmation }
    var preferredISOWeekdays: Set<Int> { planData.preferredISOWeekdays }
    var remainingOfficeDays: Int { planData.remainingOfficeDays }
    var additionalPlansNeeded: Int { planData.additionalPlansNeeded }
    var plannedCandidateDays: Int { planData.plannedCandidateDays }
    var unselectedCandidateDates: Set<Date> { planData.unselectedCandidateDates }
    var holidayDates: Set<Date> { planData.holidayDates }
    var eligibleDatesBeforeLeave: Set<Date> { planData.eligibleDatesBeforeLeave }
    var leaveDates: Set<Date> { planData.leaveDates }
    var exclusionDates: Set<Date> { planData.exclusionDates }
    var adjustedEligibleDates: Set<Date> { planData.adjustedEligibleDates }
    var completedOfficeDates: Set<Date> { planData.completedOfficeDates }
    var calendarWeeks: [OfficePlanWeek] { planData.calendarWeeks }
    var recommendedDates: [Date] { planData.recommendedDates }
    var recommendedCountsByWeek: [Date: Int] { planData.recommendedCountsByWeek }
}
