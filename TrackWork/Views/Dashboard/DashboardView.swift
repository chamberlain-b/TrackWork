import SwiftData
import SwiftUI

struct DashboardView: View {
    @Query(sort: \AttendanceDay.date) private var attendanceDays: [AttendanceDay]
    @Query(sort: \LeaveRecord.date) private var leaveRecords: [LeaveRecord]
    @Query(sort: \PublicHoliday.date) private var publicHolidays: [PublicHoliday]
    @Query(sort: \CustomExcludedDay.date) private var customExcludedDays: [CustomExcludedDay]
    @Query(sort: \PlannedOfficeDay.date) private var plannedOfficeDays: [PlannedOfficeDay]
    @Query(sort: \ComplianceRule.createdAt) private var complianceRules: [ComplianceRule]

    @State private var isPresentingOfficePlan = false
    @State private var isPresentingReviewQueue = false
    @State private var selectedDay: TodayDaySelection?
    @State private var insightsSection: InsightsSection = .overview

    private let onOpenCalendar: (() -> Void)?
    private let onOpenSettings: (() -> Void)?
    private let referenceDate: Date
    private let reportingSelection: ReportingPeriodSelection
    private let onOpenInsights: ((InsightsSection) -> Void)?
    private let calendar = Calendar.dashboardCalendar
    private let periodEvaluator = CompliancePeriodEvaluator()
    private let ruleResolver = ComplianceRuleResolver()
    private let trendCalculator = ComplianceTrendCalculator()
    private let planConfidenceCalculator = OfficePlanConfidenceCalculator()
    private let todayPresentationBuilder = TodayPresentationBuilder()
    private let attendancePresentationBuilder = AttendancePeriodPresentationBuilder()

    init(
        onOpenCalendar: (() -> Void)? = nil,
        onOpenSettings: (() -> Void)? = nil,
        referenceDate: Date = .now,
        reportingSelection: ReportingPeriodSelection? = nil,
        onOpenInsights: ((InsightsSection) -> Void)? = nil
    ) {
        self.onOpenCalendar = onOpenCalendar
        self.onOpenSettings = onOpenSettings
        self.referenceDate = referenceDate
        self.reportingSelection = reportingSelection ?? ReportingPeriodSelection(referenceDate: referenceDate)
        self.onOpenInsights = onOpenInsights
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
        // A saved policy, including an explicitly chosen zero target, is configured.
        !complianceRules.isEmpty
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

    private var monthlyAttendanceMix: AttendanceMix? {
        // Match Insights' recorded-workday mix, not the eligible-days compliance percentage.
        // The report evaluator applies work schedules, leave, holidays, exclusions and mixed-day thresholds.
        try? attendancePresentationBuilder.make(.init(
            range: ComplianceDateRange(start: currentMonthStart, end: currentMonthEnd, calendar: calendar),
            calendar: calendar,
            referenceDate: referenceDate,
            rules: complianceRules,
            attendanceDays: attendanceDays,
            leaveRecords: leaveRecords,
            publicHolidays: publicHolidays,
            customExcludedDays: customExcludedDays
        )).mix
    }

    private var todayPresentation: TodayDashboardPresentation {
        todayPresentationBuilder.makePresentation(
            TodayPresentationBuilder.Input(
                referenceDate: referenceDate,
                calendar: calendar,
                summary: summary,
                attendanceDays: attendanceDays,
                leaveRecords: leaveRecords,
                publicHolidays: publicHolidays,
                customExcludedDays: customExcludedDays,
                plannedOfficeDays: plannedOfficeDays,
                selectedISOWeekdays: selectedISOWeekdays,
                jurisdictionId: activeRule.jurisdictionId,
                targetIsConfigured: hasConfiguredTarget,
                monthlyAttendanceMix: monthlyAttendanceMix
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
        let presentation = todayPresentation
        return NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppSpacing.sm) {
                    if complianceRules.isEmpty {
                        DashboardSetupCard(onOpenSettings: onOpenSettings)
                    } else {
                        Text(
                            referenceDate.formatted(
                                .dateTime.weekday(.wide).day().month(.wide)
                            )
                        )
                        .font(.body)
                        .foregroundStyle(Color.ds.textSecondary)
                        .accessibilityIdentifier("dashboard.referenceDate")

                        TodayRunwayCard(presentation: presentation)

                        TodayMonthlyShare(presentation: presentation)

                        Divider()

                        TodaySummaryCard(
                            presentation: presentation,
                            onCorrectToday: { selectedDay = TodayDaySelection(date: today) },
                            onSelectDay: { selectedDay = TodayDaySelection(date: $0) }
                        )

                        if !hasConfiguredTarget {
                            DashboardSetupCard(onOpenSettings: onOpenSettings)
                        } else if !reviewDates.isEmpty {
                            reviewAction
                        } else if showsPlanConfidence {
                            planAction
                        }
                    }

                    insightsAction
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.xxs)
                .padding(.bottom, AppSpacing.lg)
            }
            .appScreenBackground()
            .navigationTitle("TrackWork")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Settings", systemImage: "gearshape") { onOpenSettings?() }
                        .accessibilityIdentifier("home.settings")
                }
            }
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(isPresented: $isPresentingOfficePlan) {
                OfficePlanView(
                    displayedMonth: currentMonthStart,
                    referenceDate: referenceDate
                )
            }
            .navigationDestination(isPresented: $isPresentingReviewQueue) {
                ReviewQueueView(referenceDate: referenceDate)
            }
            .sheet(item: $selectedDay) { selection in
                DashboardDayEditorSheet(date: selection.date)
                    .presentationDetents([.large])
            }
        }
    }

    private var reviewAction: some View {
        Button { isPresentingReviewQueue = true } label: {
            supportActionLabel(
                title: reviewDates.count == 1 ? "1 earlier day needs review" : "\(reviewDates.count) earlier days need review",
                detail: "Review attendance",
                systemImage: "exclamationmark.circle"
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens days that need review")
        .accessibilityIdentifier("dashboard.reviewAction")
    }

    private var planAction: some View {
        Button(action: openPlanConfidenceDestination) {
            supportActionLabel(title: planActionTitle, detail: planActionDetail, systemImage: "calendar.badge.clock")
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens office-day planning. Plans are reminders; only confirmed attendance counts.")
        .accessibilityIdentifier("dashboard.officePlan")
    }

    private var planActionTitle: String {
        switch planConfidence.state {
        case .targetMet: "View office plan"
        case .covered: "Plan covers target"
        case .needsReview: "Review attendance"
        case .shortfall(let count): count == 1 ? "Plan is 1 day short" : "Plan is \(count) days short"
        case .notReachable: "Target not reachable"
        }
    }

    private var planActionDetail: String {
        if let nextDate = planConfidence.nextPlannedDate {
            return "Next planned: \(nextDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))"
        }
        return "Review your office plan"
    }

    private func supportActionLabel(title: String, detail: String, systemImage: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.ds.interactionPrimary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Color.ds.textPrimary)
                Text(detail).font(.caption).foregroundStyle(Color.ds.textSecondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: AppSpacing.xs)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.ds.textTertiary)
                .accessibilityHidden(true)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var insightsAction: some View {
        if let onOpenInsights {
            Button {
                onOpenInsights(.overview)
            } label: {
                insightsActionLabel
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.insights")
        } else {
            NavigationLink {
                InsightsView(
                    selection: reportingSelection,
                    referenceDate: referenceDate,
                    section: $insightsSection
                )
            } label: {
                insightsActionLabel
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.insights")
        }
    }

    private var insightsActionLabel: some View {
        HStack(spacing: AppSpacing.sm) {
            Label("Attendance insights", systemImage: "chart.bar.xaxis")
                .font(AppTypography.headline)
            Spacer(minLength: AppSpacing.sm)
            Image(systemName: "chevron.right")
                .font(AppTypography.captionStrong)
                .accessibilityHidden(true)
        }
        .foregroundStyle(Color.ds.interactionPrimary)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityHint("Opens period summaries, trends and compliance details")
    }

    private func openPlanConfidenceDestination() {
        switch planConfidence.state {
        case .needsReview:
            isPresentingReviewQueue = true
        case .targetMet, .covered, .shortfall, .notReachable:
            isPresentingOfficePlan = true
        }
    }

}
