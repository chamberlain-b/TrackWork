import Foundation
import SwiftUI

struct HistoryOverviewCard: View {
    let dateRangeTitle: String
    let recordCount: Int
    let adjustedRecordCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(dateRangeTitle)
                .font(AppTypography.caption)
                .foregroundStyle(Color.ds.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(recordSummary)
                .font(AppTypography.captionStrong)
                .foregroundStyle(Color.ds.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("history.overview")
    }

    private var recordSummary: String {
        let days = recordCount == 1 ? "1 recorded day" : "\(recordCount) recorded days"
        guard adjustedRecordCount > 0 else { return days }
        let changes = adjustedRecordCount == 1 ? "1 manual change" : "\(adjustedRecordCount) manual changes"
        return "\(days) · \(changes)"
    }
}

struct HistoryFilterCard: View {
    @Binding var selectedPreset: CompliancePeriodPreset
    @Binding var customStart: Date
    @Binding var customEnd: Date
    @Binding var recordFilter: RecordFilter

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            CompliancePeriodControls(
                selectedPreset: $selectedPreset,
                customStart: $customStart,
                customEnd: $customEnd,
                accessibilityPrefix: "records"
            )

            Picker("Show", selection: $recordFilter) {
                ForEach(RecordFilter.allCases) { filter in
                    Text(filter.displayName).tag(filter)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("records.statusFilter")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("history.filters")
    }
}

struct HistoryMonthHeader: View {
    let title: String
    let recordCount: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.headline)
                .foregroundStyle(Color.ds.textPrimary)

            Spacer(minLength: AppSpacing.sm)

            Text(recordCount == 1 ? "1 day" : "\(recordCount) days")
                .font(AppTypography.captionStrong)
                .foregroundStyle(Color.ds.textSecondary)
        }
        .textCase(nil)
        .accessibilityElement(children: .combine)
    }
}

struct HistoryRecordGroup: Identifiable {
    let monthStart: Date
    let records: [RecordRow]

    var id: Date { monthStart }

    var title: String {
        monthStart.formatted(.dateTime.month(.wide).year())
    }
}

struct RecordRowView: View {
    let record: RecordRow

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                    dateLabel
                    Spacer(minLength: AppSpacing.sm)
                    statusPill
                }

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    dateLabel
                    statusPill
                }
            }

            if let overrideDescription {
                Label(overrideDescription, systemImage: "pencil")
                    .font(AppTypography.captionStrong)
                    .foregroundStyle(Color.ds.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let note = record.note, !note.isEmpty {
                Text(note)
                    .font(AppTypography.caption)
                    .foregroundStyle(Color.ds.textSecondary)
                    .lineLimit(3)
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityIdentifier(record.accessibilityIdentifier)
    }

    private var dateLabel: some View {
        Text(record.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year()))
            .font(AppTypography.callout.weight(.semibold))
            .foregroundStyle(Color.ds.textPrimary)
    }

    private var statusPill: some View {
        DSStatusPill(
            text: record.primaryStatus,
            systemImage: statusImage,
            style: statusStyle,
            statusColor: attendanceColor
        )
    }

    private var overrideDescription: String? {
        guard record.manualAdjustment != nil else {
            return nil
        }

        if record.detectedStatus == record.adjustedStatus {
            return "Manually confirmed as \(record.adjustedStatus)"
        }

        return "Detected \(record.detectedStatus) · changed to \(record.adjustedStatus)"
    }

    private var accessibilitySummary: String {
        var parts = [
            record.date.formatted(.dateTime.weekday(.wide).day().month(.wide).year()),
            record.primaryStatus
        ]
        if let overrideDescription {
            parts.append(overrideDescription)
        }
        if let note = record.note, !note.isEmpty {
            parts.append(note)
        }
        return parts.joined(separator: ", ")
    }

    private var statusImage: String {
        if record.leaveRecord != nil {
            return "sun.max"
        }

        if record.publicHoliday != nil {
            return "sparkles"
        }

        if record.customExcludedDay != nil {
            return "calendar.badge.minus"
        }

        switch record.attendanceDay?.finalClassification ?? .unknown {
        case .office:
            return "building.2"
        case .home:
            return "house"
        case .mixed:
            return "arrow.triangle.2.circlepath"
        case .annualLeave, .sickLeave:
            return "sun.max"
        case .publicHoliday:
            return "sparkles"
        case .weekend, .nonWorkingDay:
            return "calendar"
        case .unknown:
            return "questionmark.circle"
        }
    }

    private var attendanceColor: Color {
        if record.leaveRecord != nil { return Color.ds.leaveDay }
        if record.publicHoliday != nil { return Color.ds.publicHoliday }
        if record.customExcludedDay != nil { return Color.ds.textSecondary }
        return (record.attendanceDay?.finalClassification ?? .unknown).calendarBadgeForegroundColor
    }

    private var statusStyle: DSStatusPillStyle {
        if record.leaveRecord != nil {
            return .info
        }

        if record.publicHoliday != nil || record.customExcludedDay != nil {
            return .neutral
        }

        switch record.attendanceDay?.finalClassification ?? .unknown {
        case .office:
            return .success
        case .home, .mixed:
            return .neutral
        case .annualLeave, .sickLeave:
            return .info
        case .publicHoliday, .weekend, .nonWorkingDay:
            return .neutral
        case .unknown:
            return .warning
        }
    }
}

extension View {
    func historyCardListRow() -> some View {
        listRowInsets(
            EdgeInsets(
                top: AppSpacing.xs,
                leading: AppSpacing.screenHorizontal,
                bottom: AppSpacing.xs,
                trailing: AppSpacing.screenHorizontal
            )
        )
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}
