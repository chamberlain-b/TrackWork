import SwiftData
import SwiftUI

struct DashboardView: View {
    @Query(sort: \AttendanceDay.date) private var attendanceDays: [AttendanceDay]
    @Query(sort: \LeaveRecord.date) private var leaveRecords: [LeaveRecord]
    @Query(sort: \PublicHoliday.date) private var publicHolidays: [PublicHoliday]
    @Query(sort: \CustomExcludedDay.date) private var customExcludedDays: [CustomExcludedDay]
    @Query(sort: \PlannedOfficeDay.date) private var plannedOfficeDays: [PlannedOfficeDay]
    @Query(sort: \ComplianceRule.createdAt) private var complianceRules: [ComplianceRule]

    private let onOpenCalendar: (() -> Void)?
    private let onOpenSettings: (() -> Void)?
    private let referenceDate: Date
    private let calendar = Calendar.dashboardCalendar
    private let periodEvaluator = CompliancePeriodEvaluator()
    private let ruleResolver = ComplianceRuleResolver()
    private let trendCalculator = ComplianceTrendCalculator()
    private let planConfidenceCalculator = OfficePlanConfidenceCalculator()

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
        ruleResolver.rule(for: currentMonthEnd, from: complianceRules) ?? ComplianceRule()
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

    private var remainingPlannedOfficeDates: [Date] {
        Set(
            plannedOfficeDays.compactMap { plannedDay in
                let date = calendar.startOfDay(for: plannedDay.date)
                guard adjustedEligibleDates.contains(date),
                      date >= today,
                      !completedOfficeDates.contains(date) else {
                    return nil
                }
                return date
            }
        )
        .sorted()
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

        if possibleRemainingOfficeDates < summary.officeDaysNeeded {
            return .notReachable
        }

        return .reachable
    }

    private var planConfidence: OfficePlanConfidence {
        planConfidenceCalculator.evaluate(
            OfficePlanConfidenceCalculator.Input(
                requiredOfficeDays: summary.requiredOfficeDays,
                completedOfficeDates: completedOfficeDates,
                plannedOfficeDates: remainingPlannedOfficeDates,
                possibleRemainingOfficeDates: possibleRemainingOfficeDates,
                reviewRequiredDays: reviewDates.count,
                evaluationDate: today,
                calendar: calendar
            )
        )
    }

    private var showsPlanConfidence: Bool {
        hasConfiguredTarget
            && summary.adjustedEligibleDays > 0
            && reviewDates.isEmpty
    }

    private var recentMonthlyTrend: [ComplianceTrendPoint] {
        guard hasConfiguredTarget else {
            return []
        }

        return trendCalculator.points(
            granularity: .monthly,
            endingAt: today,
            calendar: calendar,
            rules: complianceRules,
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
                        if showsPlanConfidence {
                            Text(
                                referenceDate.formatted(
                                    .dateTime.weekday(.wide).day().month(.wide).year()
                                )
                            )
                            .font(AppTypography.callout)
                            .foregroundStyle(Color.ds.textSecondary)
                            .accessibilityIdentifier("dashboard.referenceDate")

                            DashboardPlanConfidenceCard(
                                confidence: planConfidence,
                                displayedMonth: currentMonthStart,
                                referenceDate: referenceDate
                            )
                        } else {
                            VStack(alignment: .leading, spacing: AppSpacing.cardGap) {
                                ComplianceHeroCard(
                                    monthTitle: currentMonthStart.formatted(.dateTime.month(.wide).year()),
                                    completedOfficeDays: summary.completedOfficeDays,
                                    businessDaysToDate: summary.eligibleDaysToDate,
                                    remainingOfficeDays: summary.officeDaysNeeded,
                                    requiredOfficeDays: summary.requiredOfficeDays,
                                    reviewCount: reviewDates.count,
                                    currentCompliance: summary.officeShareToDate,
                                    status: dashboardStatus,
                                    targetIsConfigured: hasConfiguredTarget
                                )

                                if !reviewDates.isEmpty {
                                    DashboardReviewAction(
                                        reviewCount: reviewDates.count
                                    )
                                } else if !hasPeriodData {
                                    DashboardStartAction(onOpenCalendar: onOpenCalendar)
                                }
                            }
                        }

                        if hasConfiguredTarget {
                            DashboardTrendPreview(points: recentMonthlyTrend)
                        }

                        if !showsPlanConfidence {
                            UpcomingOfficePlanSection(
                                plannedDates: remainingPlannedOfficeDates,
                                displayedMonth: currentMonthStart,
                                referenceDate: referenceDate
                            )
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.vertical, AppSpacing.lg)
            }
            .appScreenBackground()
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        QuickCheckInView()
                    } label: {
                        Label("Check In", systemImage: "location.circle")
                    }
                    .accessibilityHint("Checks whether you are at a saved home or office location")
                    .accessibilityIdentifier("dashboard.quickCheckIn")
                }
            }
        }
    }

}
