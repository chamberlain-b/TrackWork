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

    private let usesNavigationStack: Bool
    private let calendar = Calendar.complianceCalendar
    private let periodEvaluator = CompliancePeriodEvaluator()

    init(usesNavigationStack: Bool = true) {
        self.usesNavigationStack = usesNavigationStack
    }

    private var today: Date {
        calendar.startOfDay(for: .now)
    }

    private var periodRange: ComplianceDateRange {
        selectedPeriod.dateRange(
            calendar: calendar,
            now: today,
            customStart: customRangeStart,
            customEnd: customRangeEnd
        )
    }

    private var activeRule: ComplianceRule {
        complianceRules.first ?? ComplianceRule()
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
        max(0, summary.requiredOfficeDays - summary.completedOfficeDays)
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
            return "No elapsed workdays"
        }

        return targetMet ? "Meets saved target" : "Below saved target"
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
            return "Saved fixed days per period"
        case .percentageOfEligibleDays:
            return "Saved percentage rule"
        }
    }

    private var differenceValue: String {
        guard elapsedEligibleDays > 0 else {
            return "—"
        }

        switch activeRule.requirementType ?? .fixedMonthlyDays {
        case .fixedMonthlyDays:
            let difference = summary.completedOfficeDays - summary.requiredOfficeDays
            return difference > 0 ? "+\(difference) days" : "\(difference) days"
        case .percentageOfEligibleDays:
            guard let actualPercentage else {
                return "—"
            }

            let difference = actualPercentage - (activeRule.requiredPercentage ?? 0)
            return difference.formatted(.percent.precision(.fractionLength(0...1)).sign(strategy: .always()))
        }
    }

    private var differenceSubtitle: String {
        targetMet.map { $0 ? "At or above target" : "Still needed for this period" }
            ?? "No elapsed eligible days"
    }

    private var comparisonColor: Color {
        targetMet.map { $0 ? Color.ds.success : Color.ds.warning }
            ?? Color.ds.textSecondary
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
                periodSection
                DSInsightCallout(
                    icon: "checkmark.seal",
                    message: "This comparison uses the saved workdays, jurisdiction, exclusions, and compliance rule.",
                    highlightedText: "Saved rule"
                )
                ComplianceResultsSection(
                    actualPercentage: actualPercentage,
                    targetValue: targetValue,
                    targetSubtitle: targetSubtitle,
                    differenceValue: differenceValue,
                    differenceSubtitle: differenceSubtitle,
                    comparisonColor: comparisonColor,
                    completedOfficeDays: summary.completedOfficeDays,
                    eligibleWorkdays: summary.adjustedEligibleDays,
                    remainingOfficeDays: remainingOfficeDays,
                    resultText: resultText,
                    resultStyle: resultStyle
                )
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.vertical, AppSpacing.lg)
        }
        .appScreenBackground()
        .navigationTitle("Compliance")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var periodSection: some View {
        DSCard(includesShadow: false) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Compliance period")
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
