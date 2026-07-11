import SwiftData
import SwiftUI

struct DashboardView: View {
    @Query(sort: \AttendanceDay.date) private var attendanceDays: [AttendanceDay]
    @Query(sort: \LeaveRecord.date) private var leaveRecords: [LeaveRecord]
    @Query(sort: \PublicHoliday.date) private var publicHolidays: [PublicHoliday]
    @Query(sort: \CustomExcludedDay.date) private var customExcludedDays: [CustomExcludedDay]
    @Query(sort: \ComplianceRule.createdAt) private var complianceRules: [ComplianceRule]

    @State private var selectedTrendGranularity: ComplianceTrendGranularity = .monthly

    private let onOpenCalendar: (() -> Void)?
    private let onOpenSettings: (() -> Void)?
    private let referenceDate: Date
    private let calendar = Calendar.dashboardCalendar
    private let periodEvaluator = CompliancePeriodEvaluator()
    private let trendCalculator = ComplianceTrendCalculator()

    init(
        onOpenCalendar: (() -> Void)? = nil,
        onOpenSettings: (() -> Void)? = nil,
        referenceDate: Date = .now
    ) {
        self.onOpenCalendar = onOpenCalendar
        self.onOpenSettings = onOpenSettings
        self.referenceDate = referenceDate
    }
}

private extension DashboardView {
    private var currentMonthStart: Date {
        calendar.dashboardMonthStart(for: referenceDate)
    }

    private var currentMonthEnd: Date {
        calendar.dashboardMonthEnd(for: currentMonthStart)
    }

    private var today: Date {
        calendar.startOfDay(for: referenceDate)
    }

    private var activeRule: ComplianceRule {
        complianceRules.first ?? ComplianceRule()
    }

    private var ruleAdapter: DashboardRuleAdapter {
        DashboardRuleAdapter(rule: activeRule)
    }

    private var selectedISOWeekdays: Set<Int> {
        Set(activeRule.selectedISOWeekdays)
    }

    private var monthAttendanceDays: [AttendanceDay] {
        attendanceDays.filter { calendar.isDate($0.date, inSameDashboardMonthAs: currentMonthStart) }
    }

    private var monthLeaveRecords: [LeaveRecord] {
        leaveRecords.filter { calendar.isDate($0.date, inSameDashboardMonthAs: currentMonthStart) }
    }

    private var monthPublicHolidays: [PublicHoliday] {
        publicHolidays.filter { publicHoliday in
            calendar.isDate(publicHoliday.date, inSameDashboardMonthAs: currentMonthStart)
                && publicHoliday.jurisdictionId == activeRule.jurisdictionId
        }
    }

    private var monthCustomExcludedDays: [CustomExcludedDay] {
        customExcludedDays.filter {
            calendar.isDate($0.date, inSameDashboardMonthAs: currentMonthStart)
        }
    }

    private var publicHolidayDates: Set<Date> {
        Set(monthPublicHolidays.map { calendar.startOfDay(for: $0.date) })
    }

    private var summary: ComplianceSummary {
        periodEvaluator.evaluate(
            CompliancePeriodEvaluator.Input(
                range: ComplianceDateRange(
                    start: currentMonthStart,
                    end: currentMonthEnd,
                    calendar: calendar
                ),
                calendar: calendar,
                rule: activeRule,
                attendanceDays: monthAttendanceDays,
                leaveRecords: monthLeaveRecords,
                publicHolidays: monthPublicHolidays,
                customExcludedDays: monthCustomExcludedDays,
                evaluationDate: today
            )
        )
    }

    private var scheduledWorkdayDates: Set<Date> {
        BusinessDayCalculator().eligibleDates(
            from: currentMonthStart,
            through: currentMonthEnd,
            calendar: calendar,
            selectedISOWeekdays: selectedISOWeekdays,
            publicHolidays: []
        )
    }

    private var eligibleDatesBeforeLeave: Set<Date> {
        BusinessDayCalculator().eligibleDates(
            from: currentMonthStart,
            through: currentMonthEnd,
            calendar: calendar,
            selectedISOWeekdays: selectedISOWeekdays,
            publicHolidays: publicHolidayDates
        )
    }

    private var adjustedEligibleDates: Set<Date> {
        eligibleDatesBeforeLeave
            .subtracting(leaveExclusionDates)
            .subtracting(customExclusionDates)
    }

    private var elapsedEligibleDates: Set<Date> {
        adjustedEligibleDates.filter { $0 < today && $0 <= currentMonthEnd }
    }

    private var eligibleDatesThroughToday: Set<Date> {
        adjustedEligibleDates.filter { $0 <= today && $0 <= currentMonthEnd }
    }

    private var confirmedDatesThroughToday: Set<Date> {
        Set(
            monthAttendanceDays.compactMap { attendanceDay in
                let date = calendar.startOfDay(for: attendanceDay.date)
                guard eligibleDatesThroughToday.contains(date),
                      let finalClassification = attendanceDay.finalClassification,
                      finalClassification != .unknown
                else {
                    return nil
                }

                return date
            }
        )
    }

    private var resolvedElapsedDates: Set<Date> {
        confirmedDatesThroughToday.intersection(elapsedEligibleDates)
    }

    private var reviewDates: Set<Date> {
        elapsedEligibleDates.subtracting(resolvedElapsedDates)
    }

    private var targetProgress: Double {
        guard summary.requiredOfficeDays > 0 else {
            return 0
        }

        return min(Double(summary.completedOfficeDays) / Double(summary.requiredOfficeDays), 1)
    }

    private var remainingOfficeDays: Int {
        max(0, summary.requiredOfficeDays - summary.completedOfficeDays)
    }

    private var leaveExclusionCounts: [LeaveType: Int] {
        let eligibleDates = eligibleDatesBeforeLeave
        let groupedLeaveRecords = Dictionary(grouping: monthLeaveRecords) { leaveRecord in
            calendar.startOfDay(for: leaveRecord.date)
        }

        return groupedLeaveRecords.reduce(into: [:]) { counts, entry in
            let leaveType = entry.value
                .filter { leaveRecord in leaveRecord.duration == .fullDay }
                .sorted { DashboardDataAdapter.leaveRecordSort($0, $1) }
                .compactMap(\.leaveType)
                .first

            guard eligibleDates.contains(entry.key), let leaveType
            else {
                return
            }

            counts[leaveType, default: 0] += 1
        }
    }

    private var annualLeaveExcludedDays: Int {
        leaveExclusionCounts[.annualLeave, default: 0]
    }

    private var sickLeaveExcludedDays: Int {
        leaveExclusionCounts[.sickLeave, default: 0]
    }

    private var publicHolidaysExcludedDays: Int {
        scheduledWorkdayDates.intersection(publicHolidayDates).count
    }

    private var leaveExclusionDates: Set<Date> {
        Set(
            monthLeaveRecords.compactMap { leaveRecord in
                guard leaveRecord.duration == .fullDay else {
                    return nil
                }

                let date = calendar.startOfDay(for: leaveRecord.date)
                return eligibleDatesBeforeLeave.contains(date) ? date : nil
            }
        )
    }

    private var customExclusionDates: Set<Date> {
        Set(
            monthCustomExcludedDays.compactMap { excludedDay in
                let date = calendar.startOfDay(for: excludedDay.date)
                guard eligibleDatesBeforeLeave.contains(date),
                      !leaveExclusionDates.contains(date) else {
                    return nil
                }

                return date
            }
        )
    }

    private var completedOfficeDates: Set<Date> {
        Set(
            monthAttendanceDays.compactMap { attendanceDay in
                let date = calendar.startOfDay(for: attendanceDay.date)
                guard adjustedEligibleDates.contains(date), date <= today else {
                    return nil
                }

                switch attendanceDay.finalClassification {
                case .office:
                    return date
                case .mixed where attendanceDay.officeMinutes >= activeRule.minimumOfficeMinutes:
                    return date
                default:
                    return nil
                }
            }
        )
    }

    private var possibleRemainingOfficeDates: Int {
        adjustedEligibleDates.filter { date in
            date >= today && !completedOfficeDates.contains(date)
        }.count
    }

    private var hasPeriodData: Bool {
        !monthAttendanceDays.isEmpty || !monthLeaveRecords.isEmpty
    }

    private var hasConfiguredTarget: Bool {
        switch activeRule.requirementType ?? .fixedMonthlyDays {
        case .fixedMonthlyDays:
            return (activeRule.fixedRequiredDays ?? 0) > 0
        case .percentageOfEligibleDays:
            return (activeRule.requiredPercentage ?? 0) > 0
        }
    }

    private var dashboardStatus: DashboardStatus {
        guard hasConfiguredTarget else {
            return .notConfigured
        }

        guard summary.adjustedEligibleDays > 0 else {
            return .noEligibleDays
        }

        if !reviewDates.isEmpty {
            return .needsReview
        }

        guard hasPeriodData else {
            return .ready
        }

        if summary.completedOfficeDays >= summary.requiredOfficeDays {
            return .complete
        }

        if possibleRemainingOfficeDates < remainingOfficeDays {
            return .notReachable
        }

        return .reachable
    }

    private var requirementExplanation: String {
        ruleAdapter.requirementExplanation(for: summary)
    }

    private var jurisdictionName: String {
        ruleAdapter.jurisdictionName
    }

    private var recentTrend: [ComplianceTrendPoint] {
        guard !complianceRules.isEmpty else {
            return []
        }

        return trendCalculator.points(
            granularity: selectedTrendGranularity,
            endingAt: today,
            calendar: calendar,
            rule: activeRule,
            attendanceDays: attendanceDays,
            leaveRecords: leaveRecords,
            publicHolidays: publicHolidays,
            customExcludedDays: customExcludedDays
        )
    }

}

extension DashboardView {
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppSpacing.xl) {
                    if complianceRules.isEmpty {
                        DashboardSetupCard(onOpenSettings: onOpenSettings)
                    } else {
                        VStack(alignment: .leading, spacing: AppSpacing.cardGap) {
                            ComplianceHeroCard(
                                monthTitle: currentMonthStart.formatted(.dateTime.month(.wide).year()),
                                completedOfficeDays: summary.completedOfficeDays,
                                requiredOfficeDays: summary.requiredOfficeDays,
                                remainingOfficeDays: remainingOfficeDays,
                                availableOfficeDays: possibleRemainingOfficeDates,
                                progress: targetProgress,
                                status: dashboardStatus,
                                targetIsConfigured: hasConfiguredTarget
                            )

                            if !reviewDates.isEmpty {
                                DashboardReviewAction(
                                    reviewCount: reviewDates.count,
                                    onOpenCalendar: onOpenCalendar
                                )
                            } else if !hasPeriodData {
                                DashboardStartAction(onOpenCalendar: onOpenCalendar)
                            }
                        }

                        MonthAtAGlanceSection(
                            eligibleDaysToDate: eligibleDatesThroughToday.count,
                            confirmedDays: confirmedDatesThroughToday.count,
                            officeDays: completedOfficeDates.intersection(eligibleDatesThroughToday).count,
                            reviewDays: reviewDates.count
                        )

                        if hasConfiguredTarget {
                            RecentTrendCard(
                                points: recentTrend,
                                selectedGranularity: $selectedTrendGranularity
                            )
                        }

                        MonthCalculationCard(
                            scheduledWorkdays: scheduledWorkdayDates.count,
                            publicHolidays: publicHolidaysExcludedDays,
                            annualLeave: annualLeaveExcludedDays,
                            sickLeave: sickLeaveExcludedDays,
                            customExcluded: summary.customExcludedDays,
                            eligibleWorkdays: summary.adjustedEligibleDays,
                            requiredOfficeDays: summary.requiredOfficeDays,
                            jurisdictionName: jurisdictionName,
                            explanation: requirementExplanation
                        )
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.vertical, AppSpacing.lg)
            }
            .appScreenBackground()
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.large)
        }
    }

}
