import SwiftData
import SwiftUI

struct DashboardView: View {
    @Query(sort: \AttendanceDay.date) private var attendanceDays: [AttendanceDay]
    @Query(sort: \LeaveRecord.date) private var leaveRecords: [LeaveRecord]
    @Query(sort: \PublicHoliday.date) private var publicHolidays: [PublicHoliday]
    @Query(sort: \ComplianceRule.createdAt) private var complianceRules: [ComplianceRule]

    private let calendar = Calendar.dashboardCalendar
    private let calculator = ComplianceCalculator()

    private var currentMonthStart: Date {
        calendar.monthStart(for: .now)
    }

    private var currentMonthEnd: Date {
        calendar.monthEnd(for: currentMonthStart)
    }

    private var activeRule: ComplianceRule {
        complianceRules.first ?? ComplianceRule()
    }

    private var selectedISOWeekdays: Set<Int> {
        Set(activeRule.selectedISOWeekdays)
    }

    private var monthAttendanceDays: [AttendanceDay] {
        attendanceDays.filter { calendar.isDate($0.date, inSameMonthAs: currentMonthStart) }
    }

    private var monthLeaveRecords: [LeaveRecord] {
        leaveRecords.filter { calendar.isDate($0.date, inSameMonthAs: currentMonthStart) }
    }

    private var monthPublicHolidays: [PublicHoliday] {
        publicHolidays.filter { publicHoliday in
            calendar.isDate(publicHoliday.date, inSameMonthAs: currentMonthStart)
                && publicHoliday.jurisdictionId == activeRule.jurisdictionId
        }
    }

    private var publicHolidayDates: Set<Date> {
        Set(monthPublicHolidays.map { calendar.startOfDay(for: $0.date) })
    }

    private var summary: ComplianceSummary {
        calculator.calculate(
            ComplianceCalculator.Input(
                periodStart: currentMonthStart,
                periodEnd: currentMonthEnd,
                calendar: calendar,
                selectedISOWeekdays: selectedISOWeekdays,
                publicHolidays: publicHolidayDates,
                leaveRecords: monthLeaveRecords.compactMap(calculatorLeaveRecord),
                attendanceDays: monthAttendanceDays.compactMap(calculatorAttendanceDay),
                requirement: calculatorRequirement
            )
        )
    }

    private var remainingOfficeDays: Int {
        max(0, summary.requiredOfficeDays - summary.completedOfficeDays)
    }

    private var annualLeaveExcludedDays: Int {
        leaveExclusionCounts[.annualLeave, default: 0]
    }

    private var sickLeaveExcludedDays: Int {
        leaveExclusionCounts[.sickLeave, default: 0]
    }

    private var leaveExclusionCounts: [LeaveType: Int] {
        let eligibleDates = eligibleDatesBeforeLeave
        let groupedLeaveRecords = Dictionary(grouping: monthLeaveRecords) { leaveRecord in
            calendar.startOfDay(for: leaveRecord.date)
        }

        return groupedLeaveRecords.reduce(into: [:]) { counts, entry in
            let date = entry.key

            guard eligibleDates.contains(date),
                  let leaveType = entry.value
                    .sorted(by: leaveRecordSort)
                    .compactMap(\.leaveType)
                    .first
            else {
                return
            }

            counts[leaveType, default: 0] += 1
        }
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

    private var publicHolidaysExcludedDays: Int {
        publicHolidayDates.filter { date in
            selectedISOWeekdays.contains(calendar.isoWeekday(for: date))
        }.count
    }

    private var complianceStatus: ComplianceStatus {
        if summary.completedOfficeDays >= summary.requiredOfficeDays {
            return .complete
        }

        if possibleRemainingOfficeDates < remainingOfficeDays {
            return .impossible
        }

        return summary.reviewRequiredDays > 0 ? .atRisk : .onTrack
    }

    private var possibleRemainingOfficeDates: Int {
        eligibleDatesBeforeLeave.filter { date in
            date >= calendar.startOfDay(for: .now)
                && !leaveExclusionDates.contains(date)
                && !completedOfficeDates.contains(date)
        }.count
    }

    private var leaveExclusionDates: Set<Date> {
        let eligibleDates = eligibleDatesBeforeLeave

        return Set(
            monthLeaveRecords.compactMap { leaveRecord in
                guard leaveRecord.duration == .fullDay else {
                    return nil
                }

                let date = calendar.startOfDay(for: leaveRecord.date)
                return eligibleDates.contains(date) ? date : nil
            }
        )
    }

    private var completedOfficeDates: Set<Date> {
        Set(
            monthAttendanceDays.compactMap { attendanceDay in
                switch attendanceDay.finalClassification {
                case .office:
                    calendar.startOfDay(for: attendanceDay.date)
                case .mixed where attendanceDay.officeMinutes >= activeRule.minimumOfficeMinutes:
                    calendar.startOfDay(for: attendanceDay.date)
                default:
                    nil
                }
            }
        )
    }

    private var calculatorRequirement: ComplianceCalculator.Requirement {
        switch activeRule.requirementType ?? .fixedMonthlyDays {
        case .fixedMonthlyDays:
            .fixedMonthlyDays(
                baseRequiredDays: activeRule.fixedRequiredDays ?? 0,
                prorateForLeave: activeRule.prorateFixedTargetForLeave
            )
        case .percentageOfEligibleDays:
            .percentageOfEligibleDays(activeRule.requiredPercentage ?? 0)
        }
    }

    private var requirementExplanation: String {
        switch activeRule.requirementType ?? .fixedMonthlyDays {
        case .fixedMonthlyDays:
            if activeRule.prorateFixedTargetForLeave {
                return "Fixed target adjusted from \(activeRule.fixedRequiredDays ?? 0) using \(summary.adjustedEligibleDays) of \(summary.baseEligibleDays) eligible days."
            }

            return "Fixed target is not prorated for leave for this rule."
        case .percentageOfEligibleDays:
            let percentage = activeRule.requiredPercentage ?? 0
            let formattedPercentage = percentage.formatted(.percent.precision(.fractionLength(0...1)))
            return "Percentage target uses \(formattedPercentage) of \(summary.adjustedEligibleDays) leave-adjusted eligible days."
        }
    }

    private var statusColor: Color {
        switch complianceStatus {
        case .complete, .onTrack:
            Color.ds.success
        case .atRisk:
            Color.ds.warning
        case .impossible:
            Color.ds.critical
        }
    }

    private var bodyColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 154), spacing: AppSpacing.md)]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    DSInsightCallout(
                        icon: "calendar.badge.clock",
                        message: requirementExplanation,
                        highlightedText: "Requirement: \(summary.requiredOfficeDays) days"
                    )

                    LazyVGrid(columns: bodyColumns, spacing: AppSpacing.md) {
                        DSMetricTile(
                            systemImage: "calendar",
                            label: "Current month",
                            value: currentMonthStart.formatted(.dateTime.month(.wide).year()),
                            subtitle: "Calendar month"
                        )

                        DSMetricTile(
                            systemImage: "building.2",
                            label: "Completed office days",
                            value: summary.completedOfficeDays.formatted(),
                            subtitle: "Final attendance"
                        )

                        DSMetricTile(
                            systemImage: "target",
                            label: "Required office days",
                            value: summary.requiredOfficeDays.formatted(),
                            subtitle: requirementSubtitle
                        )

                        DSMetricTile(
                            systemImage: "arrow.forward.circle",
                            label: "Remaining office days",
                            value: remainingOfficeDays.formatted(),
                            subtitle: "Needed this month",
                            statusColor: remainingOfficeDays == 0 ? Color.ds.success : Color.ds.accentPrimary
                        )

                        DSMetricTile(
                            systemImage: "calendar.day.timeline.left",
                            label: "Base eligible days before leave",
                            value: summary.baseEligibleDays.formatted(),
                            subtitle: "After public holidays"
                        )

                        DSMetricTile(
                            systemImage: "sun.max",
                            label: "Annual leave excluded",
                            value: annualLeaveExcludedDays.formatted(),
                            subtitle: "Eligible days removed"
                        )

                        DSMetricTile(
                            systemImage: "cross.case",
                            label: "Sick leave excluded",
                            value: sickLeaveExcludedDays.formatted(),
                            subtitle: "Eligible days removed"
                        )

                        DSMetricTile(
                            systemImage: "calendar.badge.checkmark",
                            label: "Adjusted eligible compliance days",
                            value: summary.adjustedEligibleDays.formatted(),
                            subtitle: "After leave"
                        )

                        DSMetricTile(
                            systemImage: "sparkles",
                            label: "Public holidays excluded",
                            value: publicHolidaysExcludedDays.formatted(),
                            subtitle: activeRule.jurisdictionId
                        )

                        DSMetricTile(
                            systemImage: complianceStatus.systemImage,
                            label: "Compliance status",
                            value: complianceStatus.displayName,
                            subtitle: statusSubtitle,
                            statusColor: statusColor
                        )

                        DSMetricTile(
                            systemImage: "exclamationmark.bubble",
                            label: "Days requiring review",
                            value: summary.reviewRequiredDays.formatted(),
                            subtitle: "Unknown final status",
                            statusColor: summary.reviewRequiredDays == 0 ? Color.ds.success : Color.ds.warning
                        )
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.vertical, AppSpacing.lg)
            }
            .appScreenBackground()
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var requirementSubtitle: String {
        switch activeRule.requirementType ?? .fixedMonthlyDays {
        case .fixedMonthlyDays:
            activeRule.prorateFixedTargetForLeave ? "Leave-adjusted fixed target" : "Fixed monthly target"
        case .percentageOfEligibleDays:
            "Based on adjusted eligible days"
        }
    }

    private var statusSubtitle: String {
        switch complianceStatus {
        case .complete:
            "Requirement met"
        case .onTrack:
            "Achievable this month"
        case .atRisk:
            "Review unknown days"
        case .impossible:
            "Not enough eligible days left"
        }
    }

    private func calculatorLeaveRecord(_ leaveRecord: LeaveRecord) -> ComplianceCalculator.LeaveRecord? {
        guard let leaveType = leaveRecord.leaveType,
              let duration = leaveRecord.duration
        else {
            return nil
        }

        return ComplianceCalculator.LeaveRecord(
            date: leaveRecord.date,
            type: leaveType,
            duration: duration
        )
    }

    private func calculatorAttendanceDay(_ attendanceDay: AttendanceDay) -> ComplianceCalculator.AttendanceDay? {
        guard let finalClassification = attendanceDay.finalClassification else {
            return nil
        }

        return ComplianceCalculator.AttendanceDay(
            date: attendanceDay.date,
            finalClassification: finalClassification,
            officeMinutes: attendanceDay.officeMinutes
        )
    }

    private func leaveRecordSort(_ lhs: LeaveRecord, _ rhs: LeaveRecord) -> Bool {
        if lhs.date != rhs.date {
            return lhs.date < rhs.date
        }

        return lhs.leaveTypeRaw < rhs.leaveTypeRaw
    }
}

private extension ComplianceStatus {
    var systemImage: String {
        switch self {
        case .complete:
            "checkmark.seal"
        case .onTrack:
            "gauge.with.dots.needle.bottom.50percent"
        case .atRisk:
            "exclamationmark.triangle"
        case .impossible:
            "xmark.octagon"
        }
    }
}

private extension Calendar {
    static var dashboardCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = .autoupdatingCurrent
        calendar.timeZone = .autoupdatingCurrent
        calendar.firstWeekday = 2
        return calendar
    }

    func monthStart(for date: Date) -> Date {
        dateInterval(of: .month, for: date)?.start ?? startOfDay(for: date)
    }

    func monthEnd(for date: Date) -> Date {
        guard let monthInterval = dateInterval(of: .month, for: date),
              let finalDate = self.date(byAdding: .day, value: -1, to: monthInterval.end)
        else {
            return startOfDay(for: date)
        }

        return startOfDay(for: finalDate)
    }

    func isDate(_ date: Date, inSameMonthAs referenceDate: Date) -> Bool {
        let components = self.dateComponents([.year, .month], from: date)
        let referenceComponents = self.dateComponents([.year, .month], from: referenceDate)
        return components.year == referenceComponents.year
            && components.month == referenceComponents.month
    }

    func isoWeekday(for date: Date) -> Int {
        let weekday = component(.weekday, from: date)
        return weekday == 1 ? 7 : weekday - 1
    }
}

#Preview {
    DashboardView()
        .modelContainer(PreviewData.modelContainer())
}
