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

struct DayDetailStatusFields: View {
    @Binding var selectedStatus: AttendanceClassification
    @Binding var selectedReason: OverrideReason

    let isStatusLocked: Bool
    let finalStatus: AttendanceClassification
    let requiresOverrideReason: Bool

    var body: some View {
        Picker("Status", selection: $selectedStatus) {
            ForEach(DayDetailStatusOptions.editable) { status in
                Text(status.displayName)
                    .tag(status)
            }
        }
        .pickerStyle(.menu)
        .disabled(isStatusLocked)
        .accessibilityIdentifier("dayDetail.manualStatus")

        if isStatusLocked {
            Label(
                "\(finalStatus.displayName) is used for this day.",
                systemImage: "info.circle"
            )
            .font(AppTypography.callout)
            .foregroundStyle(Color.ds.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        if requiresOverrideReason {
            Picker("Override reason", selection: $selectedReason) {
                ForEach(OverrideReason.allCases) { reason in
                    Text(reason.displayName)
                        .tag(reason)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("dayDetail.overrideReason")
        }
    }
}

struct DayDetailLeaveFields: View {
    @Binding var selectedLeave: LeaveSelection

    var body: some View {
        Picker("Full-day leave", selection: $selectedLeave) {
            ForEach(LeaveSelection.allCases) { selection in
                Text(selection.displayName)
                    .tag(selection)
            }
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("dayDetail.leaveType")
    }
}

struct DayDetailExclusionFields: View {
    @Binding var isExcluded: Bool
    @Binding var reason: String

    var body: some View {
        Toggle("Exclude from requirement", isOn: $isExcluded)
            .tint(Color.ds.accentPrimary)
            .accessibilityIdentifier("dayDetail.customExcluded")

        if isExcluded {
            TextField("Reason (optional)", text: $reason, axis: .vertical)
                .lineLimit(2...4)
                .accessibilityIdentifier("dayDetail.customExclusionReason")
        }
    }
}

struct DayDetailNoteField: View {
    @Binding var note: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Note")
                .font(AppTypography.body)
                .foregroundStyle(Color.ds.textPrimary)

            TextEditor(text: $note)
                .frame(minHeight: 80)
                .accessibilityLabel("Attendance note")
                .accessibilityIdentifier("dayDetail.note")

            Text("Notes do not change attendance status.")
                .font(AppTypography.caption)
                .foregroundStyle(Color.ds.textSecondary)
        }
    }
}

struct DayDetailStatusDetails: View {
    let detectedStatus: AttendanceClassification
    let finalStatus: AttendanceClassification
    let isUpcoming: Bool
    let complianceTreatment: ComplianceTreatment

    var body: some View {
        if isUpcoming {
            Label(
                "Confirm attendance on or after this date.",
                systemImage: "calendar.badge.clock"
            )
            .font(AppTypography.callout)
            .foregroundStyle(Color.ds.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        } else {
            DetailInfoRow(
                title: "Detected status",
                value: detectedStatus.displayName,
                color: detectedStatus.calendarBadgeForegroundColor
            )
            DetailInfoRow(
                title: "Final status",
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
}

struct DayDetailEligibilityDetails: View {
    let title: String
    let impact: String
    let explanation: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            DetailInfoRow(title: title, value: impact, color: color)
            Text(explanation)
                .font(AppTypography.caption)
                .foregroundStyle(Color.ds.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct DayDetailHolidayDetails: View {
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
        DetailInfoRow(
            title: "Holiday source",
            value: holiday.sourceName,
            color: Color.ds.textSecondary
        )

        if let sourceURL {
            Link(destination: sourceURL) {
                Label("Official source", systemImage: "arrow.up.right.square")
            }
            .accessibilityIdentifier("dayDetail.publicHolidaySource")
        }
    }
}

struct DayDetailAttendanceDetails: View {
    let attendanceDay: AttendanceDay

    var body: some View {
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
            title: "Saved treatment",
            value: attendanceDay.complianceTreatment?.displayName
                ?? ComplianceTreatment.requiresReview.displayName,
            color: Color.ds.textSecondary
        )
    }
}

private struct DetailInfoRow: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                rowTitle
                Spacer(minLength: AppSpacing.sm)
                rowValue
                    .multilineTextAlignment(.trailing)
            }

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                rowTitle
                rowValue
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var rowTitle: some View {
        Text(title)
            .font(AppTypography.callout)
            .foregroundStyle(Color.ds.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var rowValue: some View {
        Text(value)
            .font(AppTypography.callout.weight(.semibold))
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }
}
