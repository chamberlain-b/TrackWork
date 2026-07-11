import SwiftUI

enum DayDetailStatusOptions {
    static let editable: [AttendanceClassification] = [
        .office,
        .home,
        .mixed,
        .unknown
    ]
}

enum LeaveSelection: String, CaseIterable, Identifiable {
    case none
    case annualLeave
    case sickLeave

    var id: String { rawValue }

    init(leaveType: LeaveType?) {
        switch leaveType {
        case .annualLeave:
            self = .annualLeave
        case .sickLeave:
            self = .sickLeave
        case nil:
            self = .none
        }
    }

    var displayName: String {
        switch self {
        case .none:
            "None"
        case .annualLeave:
            LeaveType.annualLeave.displayName
        case .sickLeave:
            LeaveType.sickLeave.displayName
        }
    }

    var leaveType: LeaveType? {
        switch self {
        case .none:
            nil
        case .annualLeave:
            .annualLeave
        case .sickLeave:
            .sickLeave
        }
    }
}

struct DayDetailHeaderCard: View {
    let date: Date
    let detectedStatus: AttendanceClassification
    let finalStatus: AttendanceClassification
    let isUpcoming: Bool
    let complianceTreatment: ComplianceTreatment

    var body: some View {
        DSCard(includesShadow: false) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(alignment: .top, spacing: AppSpacing.md) {
                    dateTitle
                    Spacer(minLength: AppSpacing.sm)
                    statusPill
                }

                Divider()
                    .overlay(Color.ds.separator)

                if isUpcoming {
                    Label(
                        "Attendance can be confirmed on or after this date.",
                        systemImage: "calendar.badge.clock"
                    )
                    .font(AppTypography.callout)
                    .foregroundStyle(Color.ds.textSecondary)
                } else {
                    statusRows
                }
            }
        }
    }

    private var dateTitle: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(date.formatted(.dateTime.weekday(.wide)))
                .font(AppTypography.captionStrong)
                .foregroundStyle(Color.ds.textSecondary)

            Text(date.formatted(.dateTime.day().month(.wide).year()))
                .font(AppTypography.title)
                .foregroundStyle(Color.ds.textPrimary)
                .lineLimit(2)
        }
    }

    private var statusPill: some View {
        DSStatusPill(
            text: isUpcoming ? "Upcoming" : finalStatus.displayName,
            systemImage: isUpcoming ? "calendar" : "checkmark.circle.fill",
            style: isUpcoming ? .neutral : statusPillStyle
        )
    }

    private var statusRows: some View {
        VStack(spacing: AppSpacing.sm) {
            DetailInfoRow(
                title: "Detected",
                value: detectedStatus.displayName,
                color: detectedStatus.calendarBadgeForegroundColor
            )
            DetailInfoRow(
                title: "Final",
                value: finalStatus.displayName,
                color: finalStatus.calendarBadgeForegroundColor
            )
            DetailInfoRow(
                title: "Treatment",
                value: complianceTreatment.displayName,
                color: finalStatus.calendarBadgeForegroundColor
            )
        }
    }

    private var statusPillStyle: DSStatusPillStyle {
        switch finalStatus {
        case .office:
            .success
        case .mixed, .unknown:
            .warning
        case .home, .annualLeave, .sickLeave, .publicHoliday, .weekend, .nonWorkingDay:
            .neutral
        }
    }
}

struct DayDetailManualStatusCard: View {
    @Binding var selectedStatus: AttendanceClassification
    @Binding var selectedReason: OverrideReason

    let isLeaveSelected: Bool
    let requiresOverrideReason: Bool

    var body: some View {
        DSCard(includesShadow: false) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Manual status")
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(Color.ds.textPrimary)

                LabeledContent("Final status") {
                    Picker("Final status", selection: $selectedStatus) {
                        ForEach(DayDetailStatusOptions.editable) { status in
                            Text(status.displayName)
                                .tag(status)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("dayDetail.manualStatus")
                }
                .disabled(isLeaveSelected)

                if requiresOverrideReason {
                    Picker("Override reason", selection: $selectedReason) {
                        ForEach(OverrideReason.allCases) { reason in
                            Text(reason.displayName)
                                .tag(reason)
                        }
                    }
                    .accessibilityIdentifier("dayDetail.overrideReason")
                }
            }
        }
    }
}

struct DayDetailLeaveCard: View {
    @Binding var selectedLeave: LeaveSelection

    let eligibleDayImpactText: String
    let eligibleDayImpactReason: String
    let leaveReducesEligibleDay: Bool

    var body: some View {
        DSCard(includesShadow: false) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Leave")
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(Color.ds.textPrimary)

                LabeledContent("Type") {
                    Picker("Full-day leave", selection: $selectedLeave) {
                        ForEach(LeaveSelection.allCases) { selection in
                            Text(selection.displayName)
                                .tag(selection)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("dayDetail.leaveType")
                }

                if selectedLeave.leaveType != nil {
                    DetailInfoRow(
                        title: "Duration",
                        value: LeaveDuration.fullDay.displayName,
                        color: Color.ds.leaveDay
                    )
                }

                DetailInfoRow(
                    title: "Eligible impact",
                    value: eligibleDayImpactText,
                    color: leaveReducesEligibleDay ? Color.ds.leaveDay : Color.ds.textTertiary
                )

                Text(eligibleDayImpactReason)
                    .font(AppTypography.caption)
                    .foregroundStyle(Color.ds.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct DayDetailHolidayCard: View {
    let holiday: PublicHoliday

    private var sourceURL: URL? {
        guard let sourceURL = holiday.sourceURL,
              let url = URL(string: sourceURL),
              url.scheme == "https"
        else {
            return nil
        }

        return url
    }

    var body: some View {
        DSCard(includesShadow: false) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Label("Public holiday", systemImage: "sparkles")
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(Color.ds.publicHoliday)

                Text(holiday.name)
                    .font(AppTypography.body.weight(.semibold))
                    .foregroundStyle(Color.ds.textPrimary)

                DetailInfoRow(
                    title: "Source",
                    value: holiday.sourceName,
                    color: Color.ds.textSecondary
                )

                if let sourceURL {
                    Link(destination: sourceURL) {
                        Label("View official source", systemImage: "arrow.up.right.square")
                            .font(AppTypography.callout.weight(.semibold))
                    }
                    .accessibilityIdentifier("dayDetail.publicHolidaySource")
                }
            }
        }
        .accessibilityIdentifier("dayDetail.publicHoliday")
    }
}

struct DayDetailCustomExclusionCard: View {
    @Binding var isExcluded: Bool
    @Binding var reason: String

    let eligibleDayImpactText: String
    let eligibleDayImpactReason: String
    let reducesEligibleDay: Bool

    var body: some View {
        DSCard(includesShadow: false) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Toggle("Exclude from compliance requirement", isOn: $isExcluded)
                    .font(AppTypography.cardTitle)
                    .tint(Color.ds.accentPrimary)
                    .accessibilityIdentifier("dayDetail.customExcluded")

                if isExcluded {
                    TextField("Reason (optional)", text: $reason, axis: .vertical)
                        .lineLimit(2...4)
                        .accessibilityIdentifier("dayDetail.customExclusionReason")

                    DetailInfoRow(
                        title: "Eligible impact",
                        value: eligibleDayImpactText,
                        color: reducesEligibleDay ? Color.ds.textSecondary : Color.ds.textTertiary
                    )

                    Text(eligibleDayImpactReason)
                        .font(AppTypography.caption)
                        .foregroundStyle(Color.ds.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Use this for a one-off day that should not count toward the selected period.")
                        .font(AppTypography.caption)
                        .foregroundStyle(Color.ds.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

struct DayDetailAttendanceCard: View {
    let attendanceDay: AttendanceDay

    var body: some View {
        DSCard(includesShadow: false) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Attendance")
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(Color.ds.textPrimary)

                DetailInfoRow(
                    title: "Office minutes",
                    value: attendanceDay.officeMinutes.formatted(),
                    color: Color.ds.officeDay
                )
                DetailInfoRow(
                    title: "Home minutes",
                    value: attendanceDay.homeMinutes.formatted(),
                    color: Color.ds.homeDay
                )
                DetailInfoRow(
                    title: "Compliance",
                    value: attendanceDay.complianceTreatment?.displayName
                        ?? ComplianceTreatment.requiresReview.displayName,
                    color: Color.ds.info
                )
            }
        }
    }
}

struct DayDetailNoteCard: View {
    @Binding var note: String

    var body: some View {
        DSCard(includesShadow: false) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Note")
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(Color.ds.textPrimary)

                TextEditor(text: $note)
                    .frame(minHeight: 120)
                    .padding(AppSpacing.xs)
                    .background(
                        Color.ds.surfaceSecondary.opacity(0.62),
                        in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    )
                    .accessibilityLabel("Attendance note")
                    .accessibilityIdentifier("dayDetail.note")

                Text("Notes are explanatory only unless saved with a manual status or leave status.")
                    .font(AppTypography.caption)
                    .foregroundStyle(Color.ds.textSecondary)
            }
        }
    }
}

private struct DetailInfoRow: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.callout)
                .foregroundStyle(Color.ds.textSecondary)

            Spacer(minLength: AppSpacing.sm)

            Text(value)
                .font(AppTypography.callout.weight(.semibold))
                .foregroundStyle(color)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
    }
}
