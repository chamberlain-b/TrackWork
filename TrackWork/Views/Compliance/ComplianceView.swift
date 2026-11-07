import SwiftData
import SwiftUI

struct ComplianceView: View {
    @Query(sort: \AttendanceDay.date) private var attendanceDays: [AttendanceDay]
    @Query(sort: \LeaveRecord.date) private var leaveRecords: [LeaveRecord]
    @Query(sort: \PublicHoliday.date) private var publicHolidays: [PublicHoliday]
    @Query(sort: \CustomExcludedDay.date) private var customExcludedDays: [CustomExcludedDay]
    @Query(sort: \ComplianceRule.createdAt) private var complianceRules: [ComplianceRule]

    @State private var selectedPeriod: CompliancePeriodPreset = .currentMonth
    @State private var customRangeStart = Date.now
    @State private var customRangeEnd = Date.now
    @State private var selectedTrendGranularity: ComplianceTrendGranularity = .monthly

    private let usesNavigationStack: Bool
    private let title: String
    private let referenceDate: Date
    private let reportingSelection: ReportingPeriodSelection?
    private let calendar = Calendar.complianceCalendar
    private let periodEvaluator = CompliancePeriodEvaluator()
    private let ruleResolver = ComplianceRuleResolver()
    private let trendCalculator = ComplianceTrendCalculator()

    init(usesNavigationStack: Bool = true, title: String = "Compliance",
         reportingSelection: ReportingPeriodSelection? = nil, referenceDate: Date = .now) {
        self.usesNavigationStack = usesNavigationStack
        self.title = title
        self.reportingSelection = reportingSelection
        self.referenceDate = referenceDate
    }

    private var today: Date {
        calendar.startOfDay(for: referenceDate)
    }

    private var periodRange: ComplianceDateRange {
        if let reportingSelection { return reportingSelection.range(calendar: calendar, referenceDate: referenceDate) }
        return selectedPeriod.dateRange(
            calendar: calendar,
            now: today,
            customStart: customRangeStart,
            customEnd: customRangeEnd
        )
    }

    private var activeRule: ComplianceRule {
        ruleResolver.rule(for: periodRange.end, from: complianceRules) ?? ComplianceRule()
    }

    private var ruleAdapter: DashboardRuleAdapter {
        DashboardRuleAdapter(rule: activeRule)
    }

    private var holidayCoverageWarning: String? {
        HolidayCoverage.validation(for: periodRange, calendar: calendar).userFacingMessage
    }

    private var periodAttendanceDays: [AttendanceDay] {
        attendanceDays.filter { periodRange.contains($0.date, calendar: calendar) }
    }

    private var periodLeaveRecords: [LeaveRecord] {
        leaveRecords.filter { periodRange.contains($0.date, calendar: calendar) }
    }

    private var periodCustomExcludedDays: [CustomExcludedDay] {
        customExcludedDays.filter { periodRange.contains($0.date, calendar: calendar) }
    }

    private var summary: ComplianceSummary {
        periodEvaluator.evaluate(
            CompliancePeriodEvaluator.Input(
                range: periodRange,
                calendar: calendar,
                rule: activeRule,
                attendanceDays: periodAttendanceDays,
                leaveRecords: periodLeaveRecords,
                publicHolidays: publicHolidays,
                customExcludedDays: periodCustomExcludedDays,
                evaluationDate: today
            )
        )
    }

    private var elapsedEligibleDays: Int {
        summary.eligibleDaysToDate
    }

    private var actualPercentage: Double? {
        summary.officeShareToDate
    }

    private var remainingOfficeDays: Int {
        summary.officeDaysNeeded
    }

    private var targetMet: Bool? {
        guard elapsedEligibleDays > 0 else {
            return nil
        }

        switch activeRule.requirementType ?? .fixedMonthlyDays {
        case .fixedMonthlyDays:
            return summary.requiredOfficeDays > 0
                ? summary.completedOfficeDays >= summary.requiredOfficeDays
                : nil
        case .percentageOfEligibleDays:
            guard let actualPercentage else {
                return nil
            }

            return actualPercentage >= (activeRule.requiredPercentage ?? 0)
        }
    }

    private var resultStyle: DSStatusPillStyle {
        targetMet.map { $0 ? .success : .warning } ?? .neutral
    }

    private var resultText: String {
        guard let targetMet else {
            return "No eligible days yet"
        }

        guard !targetMet else {
            return "Target met"
        }

        return "Below target"
    }

    private var targetValue: String {
        switch activeRule.requirementType ?? .fixedMonthlyDays {
        case .fixedMonthlyDays:
            return "\(summary.requiredOfficeDays.formatted()) days"
        case .percentageOfEligibleDays:
            return (activeRule.requiredPercentage ?? 0)
                .formatted(.percent.precision(.fractionLength(0...1)))
        }
    }

    private var targetSubtitle: String {
        switch activeRule.requirementType ?? .fixedMonthlyDays {
        case .fixedMonthlyDays:
            return "For selected period"
        case .percentageOfEligibleDays:
            return "Of eligible workdays"
        }
    }

    private var isPercentageTarget: Bool {
        (activeRule.requirementType ?? .fixedMonthlyDays) == .percentageOfEligibleDays
    }

    private var hasConfiguredTarget: Bool {
        switch activeRule.requirementType ?? .fixedMonthlyDays {
        case .fixedMonthlyDays:
            return (activeRule.fixedRequiredDays ?? 0) > 0
        case .percentageOfEligibleDays:
            return (activeRule.requiredPercentage ?? 0) > 0
        }
    }

    private var recentTrend: [ComplianceTrendPoint] {
        guard !complianceRules.isEmpty else {
            return []
        }

        return trendCalculator.points(
            granularity: selectedTrendGranularity,
            endingAt: today,
            calendar: calendar,
            rules: complianceRules,
            attendanceDays: attendanceDays,
            leaveRecords: leaveRecords,
            publicHolidays: publicHolidays,
            customExcludedDays: customExcludedDays
        )
    }

    private var periodTitle: String {
        let start = periodRange.start.formatted(.dateTime.day().month(.abbreviated).year())
        let end = periodRange.end.formatted(.dateTime.day().month(.abbreviated).year())
        return start == end ? start : "\(start) – \(end)"
    }

    var body: some View {
        Group {
            if usesNavigationStack {
                NavigationStack {
                    screenContent
                }
            } else {
                screenContent
            }
        }
    }

    private var screenContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                if reportingSelection == nil { periodSection }
                if let holidayCoverageWarning {
                    DSInsightCallout(
                        icon: "exclamationmark.triangle.fill",
                        message: holidayCoverageWarning,
                        highlightedText: "Holiday data unavailable"
                    )
                    .accessibilityIdentifier("compliance.holidayCoverageWarning")
                }
                ComplianceResultsSection(
                    actualPercentage: actualPercentage,
                    targetValue: targetValue,
                    targetSubtitle: targetSubtitle,
                    targetPercentage: activeRule.requiredPercentage,
                    isPercentageTarget: isPercentageTarget,
                    targetMet: targetMet,
                    completedOfficeDays: summary.completedOfficeDays,
                    eligibleWorkdays: summary.adjustedEligibleDays,
                    eligibleDaysToDate: summary.eligibleDaysToDate,
                    remainingOfficeDays: remainingOfficeDays,
                    resultText: resultText,
                    resultStyle: resultStyle
                )

                if hasConfiguredTarget {
                    ComplianceCalculationDisclosure(
                        startingEligibleWorkdays: summary.baseEligibleDays,
                        excludedWorkdays: max(0, summary.baseEligibleDays - summary.adjustedEligibleDays),
                        eligibleWorkdays: summary.adjustedEligibleDays,
                        requiredOfficeDays: summary.requiredOfficeDays,
                        jurisdictionName: ruleAdapter.jurisdictionName,
                        explanation: ruleAdapter.requirementExplanation(for: summary)
                    )

                    RecentTrendCard(
                        points: recentTrend,
                        selectedGranularity: $selectedTrendGranularity
                    )
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.vertical, AppSpacing.lg)
        }
        .appScreenBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(title == "Insights" ? .large : .inline)
    }

    private var periodSection: some View {
        DSCard(includesShadow: false) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Period")
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(Color.ds.textPrimary)

                CompliancePeriodControls(
                    selectedPreset: $selectedPeriod,
                    customStart: $customRangeStart,
                    customEnd: $customRangeEnd,
                    accessibilityPrefix: "compliance"
                )

                Label(periodTitle, systemImage: "calendar")
                    .font(AppTypography.caption)
                    .foregroundStyle(Color.ds.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private extension Calendar {
    static var complianceCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = .autoupdatingCurrent
        calendar.timeZone = .autoupdatingCurrent
        calendar.firstWeekday = 2
        return calendar
    }
}

#Preview {
    ComplianceView()
        .modelContainer(PreviewData.modelContainer())
}
