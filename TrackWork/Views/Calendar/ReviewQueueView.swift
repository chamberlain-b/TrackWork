import SwiftData
import SwiftUI

struct ReviewQueueView: View {
    @Query(sort: \AttendanceDay.date) private var attendanceDays: [AttendanceDay]
    @Query(sort: \LeaveRecord.date) private var leaveRecords: [LeaveRecord]
    @Query(sort: \PublicHoliday.date) private var publicHolidays: [PublicHoliday]
    @Query(sort: \CustomExcludedDay.date) private var customExcludedDays: [CustomExcludedDay]
    @Query(sort: \ComplianceRule.createdAt) private var complianceRules: [ComplianceRule]

    private let referenceDate: Date
    private let calendar = Calendar.workTrackCalendar
    private let reviewCalculator = ReviewDateCalculator()
    private let ruleResolver = ComplianceRuleResolver()

    init(referenceDate: Date = .now) {
        self.referenceDate = referenceDate
    }

    private var range: ComplianceDateRange {
        ComplianceDateRange(
            start: calendar.complianceMonthStart(for: referenceDate),
            end: calendar.complianceMonthEnd(for: referenceDate),
            calendar: calendar
        )
    }

    private var activeRule: ComplianceRule {
        ruleResolver.rule(for: range.end, from: complianceRules) ?? ComplianceRule()
    }

    private var reviewDates: [Date] {
        reviewCalculator.datesNeedingReview(
            ReviewDateCalculator.Input(
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

    var body: some View {
        List {
            if reviewDates.isEmpty {
                ContentUnavailableView(
                    "All caught up",
                    systemImage: "checkmark.circle",
                    description: Text("No days need review this month.")
                )
                .listRowBackground(Color.clear)
            } else {
                Section {
                    if let firstDate = reviewDates.first {
                        dayLink(for: firstDate) {
                            Label("Review next day", systemImage: "arrow.right.circle.fill")
                                .font(AppTypography.headline)
                                .foregroundStyle(Color.ds.accentPrimary)
                        }
                        .accessibilityIdentifier("reviewQueue.next")
                    }
                } footer: {
                    Text("Confirm attendance, leave or an exclusion.")
                }

                Section("To review") {
                    ForEach(reviewDates, id: \.self) { date in
                        dayLink(for: date) {
                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(Color.ds.warning)
                                    .accessibilityHidden(true)

                                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                    Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                                        .font(AppTypography.headline)
                                    Text("Attendance missing")
                                        .font(AppTypography.caption)
                                        .foregroundStyle(Color.ds.textSecondary)
                                }
                            }
                            .padding(.vertical, AppSpacing.xxs)
                        }
                        .accessibilityIdentifier(calendar.calendarDayAccessibilityIdentifier(for: date))
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .appScreenBackground()
        .navigationTitle("Review Days")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func dayLink<Label: View>(
        for date: Date,
        @ViewBuilder label: () -> Label
    ) -> some View {
        NavigationLink {
            DayDetailView(
                date: date,
                attendanceDay: attendanceDay(on: date),
                leaveRecord: leaveRecord(on: date),
                publicHoliday: publicHoliday(on: date),
                customExcludedDay: customExcludedDay(on: date)
            )
        } label: {
            label()
        }
    }

    private func attendanceDay(on date: Date) -> AttendanceDay? {
        attendanceDays.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private func leaveRecord(on date: Date) -> LeaveRecord? {
        leaveRecords.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private func publicHoliday(on date: Date) -> PublicHoliday? {
        ActiveJurisdictionHolidayResolver.holiday(
            on: date,
            from: publicHolidays,
            jurisdictionId: activeRule.jurisdictionId,
            calendar: calendar
        )
    }

    private func customExcludedDay(on date: Date) -> CustomExcludedDay? {
        customExcludedDays.first { calendar.isDate($0.date, inSameDayAs: date) }
    }
}

#Preview {
    NavigationStack {
        ReviewQueueView(referenceDate: PreviewData.dashboardReferenceDate)
    }
    .modelContainer(PreviewData.modelContainer())
}
