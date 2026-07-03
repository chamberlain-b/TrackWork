import SwiftData
import SwiftUI

struct ComplianceView: View {
    @Query(sort: \AttendanceDay.date) private var attendanceDays: [AttendanceDay]
    @Query(sort: \LeaveRecord.date) private var leaveRecords: [LeaveRecord]
    @Query(sort: \PublicHoliday.date) private var publicHolidays: [PublicHoliday]
    @Query(sort: \ComplianceRule.createdAt) private var complianceRules: [ComplianceRule]

    @State private var selectedMonth = Date.now
    @State private var thresholdInput = 50.0

    private let calendar = Calendar.complianceCalendar
    private let calculator = ComplianceCalculator()

    private var monthStart: Date {
        calendar.monthStart(for: selectedMonth)
    }

    private var monthEnd: Date {
        calendar.monthEnd(for: monthStart)
    }

    private var activeRule: ComplianceRule {
        complianceRules.first ?? ComplianceRule()
    }

    private var selectedISOWeekdays: Set<Int> {
        Set(activeRule.selectedISOWeekdays)
    }

    private var periodAttendanceDays: [AttendanceDay] {
        attendanceDays.filter { calendar.isDate($0.date, inSameMonthAs: monthStart) }
    }

    private var periodLeaveRecords: [LeaveRecord] {
        leaveRecords.filter { calendar.isDate($0.date, inSameMonthAs: monthStart) }
    }

    private var periodPublicHolidayDates: Set<Date> {
        Set(
            publicHolidays.compactMap { publicHoliday in
                guard calendar.isDate(publicHoliday.date, inSameMonthAs: monthStart),
                      publicHoliday.jurisdictionId == activeRule.jurisdictionId
                else {
                    return nil
                }

                return calendar.startOfDay(for: publicHoliday.date)
            }
        )
    }

    private var summary: ComplianceSummary {
        calculator.calculate(
            ComplianceCalculator.Input(
                periodStart: monthStart,
                periodEnd: monthEnd,
                calendar: calendar,
                selectedISOWeekdays: selectedISOWeekdays,
                publicHolidays: periodPublicHolidayDates,
                leaveRecords: periodLeaveRecords.compactMap(calculatorLeaveRecord),
                attendanceDays: periodAttendanceDays.compactMap(calculatorAttendanceDay),
                requirement: .percentageOfEligibleDays(threshold)
            )
        )
    }

    private var threshold: Double {
        min(max(thresholdInput, 0), 100) / 100
    }

    private var actualPercentage: Double {
        guard summary.adjustedEligibleDays > 0 else {
            return 0
        }

        return Double(summary.completedOfficeDays) / Double(summary.adjustedEligibleDays)
    }

    private var percentageDifference: Double {
        actualPercentage - threshold
    }

    private var remainingOfficeDays: Int {
        max(0, summary.requiredOfficeDays - summary.completedOfficeDays)
    }

    private var resultStyle: DSStatusPillStyle {
        summary.completedOfficeDays >= summary.requiredOfficeDays ? .success : .warning
    }

    private var resultText: String {
        summary.completedOfficeDays >= summary.requiredOfficeDays ? "Meets threshold" : "Below threshold"
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 154), spacing: AppSpacing.md)]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    monthPicker
                    thresholdSection
                    resultSection
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.vertical, AppSpacing.lg)
            }
            .appScreenBackground()
            .navigationTitle("Compliance")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                thresholdInput = (activeRule.requiredPercentage ?? 0.5) * 100
            }
        }
    }

    private var monthPicker: some View {
        HStack(spacing: AppSpacing.sm) {
            Button {
                moveMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous month")

            Text(monthStart.formatted(.dateTime.month(.wide).year()))
                .font(AppTypography.title)
                .foregroundStyle(Color.ds.textPrimary)
                .frame(maxWidth: .infinity)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Button {
                moveMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next month")
        }
        .padding(AppSpacing.sm)
        .cardSurface(includesShadow: false)
    }

    private var thresholdSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Threshold")
                .font(AppTypography.headline)
                .foregroundStyle(Color.ds.textPrimary)

            HStack(spacing: AppSpacing.md) {
                Slider(value: $thresholdInput, in: 0...100, step: 1)
                    .accessibilityLabel("Compliance threshold")

                Text(thresholdInput / 100, format: .percent.precision(.fractionLength(0)))
                    .font(AppTypography.callout.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Color.ds.textPrimary)
                    .frame(width: 56, alignment: .trailing)
            }
        }
        .padding(AppSpacing.md)
        .cardSurface(includesShadow: false)
    }

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text("Monthly result")
                    .font(AppTypography.headline)
                    .foregroundStyle(Color.ds.textPrimary)

                Spacer()

                DSStatusPill(text: resultText, systemImage: "target", style: resultStyle)
            }

            LazyVGrid(columns: columns, spacing: AppSpacing.md) {
                DSMetricTile(
                    systemImage: "percent",
                    label: "Actual compliance",
                    value: actualPercentage.formatted(.percent.precision(.fractionLength(0...1))),
                    subtitle: "Office days / work max",
                    statusColor: resultStyle == .success ? Color.ds.success : Color.ds.warning
                )

                DSMetricTile(
                    systemImage: "target",
                    label: "Required threshold",
                    value: threshold.formatted(.percent.precision(.fractionLength(0))),
                    subtitle: "Selected for this review"
                )

                DSMetricTile(
                    systemImage: "plus.forwardslash.minus",
                    label: "Difference",
                    value: percentageDifference.formatted(.percent.precision(.fractionLength(0...1))),
                    subtitle: percentageDifference >= 0 ? "Above target" : "Below target",
                    statusColor: percentageDifference >= 0 ? Color.ds.success : Color.ds.warning
                )

                DSMetricTile(
                    systemImage: "building.2",
                    label: "Completed office days",
                    value: summary.completedOfficeDays.formatted(),
                    subtitle: "Final status"
                )

                DSMetricTile(
                    systemImage: "calendar.badge.checkmark",
                    label: "Work max",
                    value: summary.adjustedEligibleDays.formatted(),
                    subtitle: "After holidays and leave"
                )

                DSMetricTile(
                    systemImage: "arrow.forward.circle",
                    label: "Office days still needed",
                    value: remainingOfficeDays.formatted(),
                    subtitle: "For this threshold",
                    statusColor: remainingOfficeDays == 0 ? Color.ds.success : Color.ds.accentPrimary
                )
            }
        }
    }

    private func moveMonth(by offset: Int) {
        guard let nextMonth = calendar.date(byAdding: .month, value: offset, to: monthStart) else {
            return
        }

        selectedMonth = nextMonth
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
}

private extension Calendar {
    static var complianceCalendar: Calendar {
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
}

#Preview {
    ComplianceView()
        .modelContainer(PreviewData.modelContainer())
}
