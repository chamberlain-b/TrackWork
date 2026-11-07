import SwiftData
import SwiftUI

struct InsightsView: View {
    let selection: ReportingPeriodSelection
    let referenceDate: Date
    @Binding var section: InsightsSection
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var scrollPosition = ScrollPosition(edge: .top)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.sectionGap) {
                    if dynamicTypeSize.isAccessibilitySize {
                        sectionPicker.pickerStyle(.menu)
                    } else {
                        sectionPicker.pickerStyle(.segmented)
                    }
                    ReportingContentView(selection: selection, referenceDate: referenceDate, section: section,
                                         onOpenInsights: { section = $0 })
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.vertical, AppSpacing.lg)
            }
            .scrollPosition($scrollPosition)
            .onChange(of: section) { _, _ in scrollPosition.scrollTo(edge: .top) }
            .appScreenBackground()
            .navigationTitle("Insights")
        }
    }

    private var sectionPicker: some View {
        Picker("Insights section", selection: $section) {
            ForEach(InsightsSection.allCases) { item in Text(item.rawValue).tag(item) }
        }
        .accessibilityIdentifier("insights.section")
    }
}

/// Shared period content ensures Home and Insights read the same selection and rules.
struct ReportingContentView: View {
    @Bindable var selection: ReportingPeriodSelection
    let referenceDate: Date
    var section: InsightsSection?
    var onOpenInsights: ((InsightsSection) -> Void)?

    @Query(sort: \AttendanceDay.date) private var attendanceDays: [AttendanceDay]
    @Query(sort: \LeaveRecord.date) private var leaveRecords: [LeaveRecord]
    @Query(sort: \PublicHoliday.date) private var publicHolidays: [PublicHoliday]
    @Query(sort: \CustomExcludedDay.date) private var customExcludedDays: [CustomExcludedDay]
    @Query(sort: \ComplianceRule.createdAt) private var rules: [ComplianceRule]
    @State private var granularity: ComplianceTrendGranularity = .monthly
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let calendar = Calendar.workTrackCalendar
    private let builder = AttendancePeriodPresentationBuilder()

    private var range: ComplianceDateRange { selection.range(calendar: calendar, referenceDate: referenceDate) }
    private var rule: ComplianceRule {
        ComplianceRuleResolver().rule(for: range.end, from: rules) ?? ComplianceRule()
    }
    private var targetIsConfigured: Bool {
        ComplianceRuleResolver().rule(for: range.end, from: rules) != nil
    }
    private var input: AttendancePeriodPresentationBuilder.Input {
        .init(range: range, calendar: calendar, referenceDate: referenceDate, rules: rules,
              attendanceDays: attendanceDays, leaveRecords: leaveRecords,
              publicHolidays: publicHolidays, customExcludedDays: customExcludedDays)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sectionGap) {
            periodControls
            if section == nil {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(greeting).font(AppTypography.title)
                    Text("Here’s your attendance at a glance.")
                        .font(AppTypography.callout).foregroundStyle(Color.ds.textSecondary)
                }
            }
            switch Result(catching: { try builder.make(input) }) {
            case .success(let presentation):
                if let warning = presentation.coverageWarning {
                    DSInsightCallout(icon: "exclamationmark.triangle", message: warning,
                                     highlightedText: "Holiday data unavailable")
                        .accessibilityIdentifier("analytics.holidayCoverageWarning")
                }
                content(presentation)
            case .failure:
                DSInsightCallout(icon: "exclamationmark.triangle", message: "Attendance could not be summarised for this period.",
                                 highlightedText: "Summary unavailable")
            }
        }
    }

    private var periodControls: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            if section == nil {
                CompliancePeriodControls(selectedPreset: $selection.preset,
                                         customStart: $selection.customStart, customEnd: $selection.customEnd,
                                         accessibilityPrefix: "home")
                periodDates
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: AppSpacing.sm) {
                        periodPicker
                        Spacer(minLength: 0)
                        periodDates.fixedSize()
                    }
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        periodPicker
                        periodDates
                    }
                }
                if selection.preset == .custom {
                    customDatePicker("Start date", date: $selection.customStart, identifier: "insights.customStartDate")
                        .onChange(of: selection.customStart) { _, start in
                            if start > selection.customEnd { selection.customEnd = start }
                        }
                    customDatePicker("End date", date: $selection.customEnd, identifier: "insights.customEndDate")
                        .onChange(of: selection.customEnd) { _, end in
                            if end < selection.customStart { selection.customStart = end }
                        }
                }
            }
        }
    }

    @ViewBuilder
    private func customDatePicker(_ title: String, date: Binding<Date>, identifier: String) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title).font(.body)
                DatePicker(title, selection: date, displayedComponents: .date)
                    .labelsHidden()
                    .accessibilityLabel(title)
                    .accessibilityIdentifier(identifier)
            }
        } else {
            DatePicker(title, selection: date, displayedComponents: .date)
                .accessibilityIdentifier(identifier)
        }
    }

    private var periodPicker: some View {
        Menu {
            Picker("Period", selection: $selection.preset) {
                ForEach(CompliancePeriodPreset.allCases) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }
        } label: {
            HStack(spacing: AppSpacing.xs) {
                Text(selection.preset.displayName)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                Image(systemName: "chevron.up.chevron.down").font(.caption.weight(.semibold))
            }
            .font(.body)
            .frame(minHeight: 44, alignment: .leading)
        }
        .accessibilityLabel("Period, \(selection.preset.displayName)")
        .accessibilityIdentifier("insights.periodPreset")
    }

    private var periodDates: some View {
        Text(periodDateText)
            .font(AppTypography.caption)
            .foregroundStyle(Color.ds.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("analytics.periodRange")
    }

    private var periodDateText: String {
        let sameYear = calendar.component(.year, from: range.start) == calendar.component(.year, from: range.end)
        let start = sameYear
            ? range.start.formatted(.dateTime.day().month(.abbreviated))
            : range.start.formatted(.dateTime.day().month(.abbreviated).year())
        return "\(start) – \(range.end.formatted(.dateTime.day().month(.abbreviated).year()))"
    }

    @ViewBuilder
    private func content(_ presentation: AttendancePeriodPresentation) -> some View {
        switch section {
        case nil:
            DSComplianceProgress(summary: presentation.summary, targetIsConfigured: targetIsConfigured)
            Divider()
            sectionHeading("Where you worked", destination: .overview)
            DSAttendanceMix(mix: presentation.mix, showsExplanation: false)
            sectionHeading("Attendance trend", destination: .trends)
                .accessibilityIdentifier("dashboard.trends")
            trendContent(compact: true)
        case .overview:
            targetSummary(presentation.summary)
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                heading("Where you worked")
                    .accessibilityIdentifier("insights.workMixHeading")
                DSAttendanceMix(mix: presentation.mix)
            }
            Divider()
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                sectionHeading("Office attendance", destination: .trends)
                    .accessibilityIdentifier("insights.officeAttendance")
                trendContent(compact: true)
            }
            Divider()
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                sectionHeading("Leave & exclusions", destination: .breakdown)
                eligibility(presentation.summary)
            }
            Divider()
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                heading("Attendance pattern")
                AttendanceHeatmapView(days: presentation.days, calendar: calendar)
            }
        case .trends:
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                heading("Attendance trends")
                if dynamicTypeSize.isAccessibilitySize { trendPicker.pickerStyle(.menu) }
                else { trendPicker.pickerStyle(.segmented) }
                trendContent(compact: false)
            }
            .padding(AppSpacing.lg)
            .summaryCardSurface()
        case .breakdown:
            targetSummary(presentation.summary)
            heading("Leave & exclusions")
            eligibility(presentation.summary)
            ComplianceCalculationDisclosure(
                startingEligibleWorkdays: presentation.summary.baseEligibleDays,
                excludedWorkdays: max(0, presentation.summary.baseEligibleDays - presentation.summary.adjustedEligibleDays),
                eligibleWorkdays: presentation.summary.adjustedEligibleDays,
                requiredOfficeDays: presentation.summary.requiredOfficeDays,
                jurisdictionName: DashboardRuleAdapter(rule: rule).jurisdictionName,
                explanation: DashboardRuleAdapter(rule: rule).requirementExplanation(for: presentation.summary)
            )
            DSMetricStrip(metrics: [
                .init(label: "Eligible through today", value: presentation.summary.eligibleDaysToDate.formatted()),
                .init(label: "Office days still needed", value: presentation.summary.officeDaysNeeded.formatted()),
                .init(label: "Days needing review", value: presentation.summary.reviewRequiredDays.formatted())
            ])
            heading("Recorded location mix")
            DSAttendanceMix(mix: presentation.mix)
            NavigationLink("Compliance details") {
                ComplianceView(usesNavigationStack: false, title: "Compliance details", reportingSelection: selection,
                               referenceDate: referenceDate)
            }
            .frame(minHeight: 44)
        }
    }

    private func targetPresentation(_ summary: ComplianceSummary) -> InsightsTargetPresentation {
        InsightsTargetPresentation(summary: summary, targetIsConfigured: targetIsConfigured,
                                   range: range, referenceDate: referenceDate, calendar: calendar)
    }

    private func targetSummary(_ summary: ComplianceSummary) -> some View {
        InsightsTargetSummary(summary: summary, presentation: targetPresentation(summary))
    }

    private func eligibility(_ summary: ComplianceSummary) -> some View {
        InsightsEligibilitySummary(summary: summary, eligibleLeaveDays: targetPresentation(summary).eligibleLeaveDays)
    }

    @ViewBuilder
    private func trendContent(compact: Bool) -> some View {
        switch Result(catching: { try builder.trends(input, granularity: compact ? .monthly : granularity) }) {
        case .success(let points):
            if let first = points.first, let last = points.last,
               let warning = HolidayCoverage.validation(
                for: ComplianceDateRange(start: first.point.range.start, end: last.point.range.end, calendar: calendar),
                calendar: calendar
               ).userFacingMessage {
                Text(warning).font(AppTypography.caption).foregroundStyle(Color.ds.textSecondary)
            }
            if section == nil { DSAttendanceTrend(points: points, compact: compact) }
            else { InsightsOfficeTrend(points: points) }
        case .failure:
            Text("Trend data is unavailable.").foregroundStyle(Color.ds.textSecondary)
        }
    }

    private var trendPicker: some View {
        Picker("Trend period", selection: $granularity) {
            ForEach(ComplianceTrendGranularity.allCases) { item in Text(item.displayName).tag(item) }
        }
        .accessibilityIdentifier("dashboard.trendGranularity")
    }

    @ViewBuilder
    private func sectionHeading(_ title: String, destination: InsightsSection) -> some View {
        if let onOpenInsights {
            Button { onOpenInsights(destination) } label: {
                HStack {
                    heading(title)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(DSPressButtonStyle())
        } else { heading(title) }
    }

    private func heading(_ title: String) -> some View {
        Text(title).font(AppTypography.sectionTitle).foregroundStyle(Color.ds.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }

    private var greeting: String {
        switch calendar.component(.hour, from: referenceDate) {
        case 0..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }
}
