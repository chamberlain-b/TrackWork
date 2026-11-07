import SwiftUI

struct AttendanceHeatmapView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .caption) private var cellSize: CGFloat = 30
    @ScaledMetric(relativeTo: .caption) private var weekdayWidth: CGFloat = 36
    @ScaledMetric(relativeTo: .caption) private var monthLabelHeight: CGFloat = 20
    let days: [AttendanceHeatmapDay]
    let calendar: Calendar

    private var paddedDays: [AttendanceHeatmapDay?] {
        guard let first = days.first else { return [] }
        let weekday = calendar.component(.weekday, from: first.date)
        let mondayOffset = (weekday + 5) % 7
        return Array(repeating: nil, count: mondayOffset) + days.map(Optional.some)
    }

    var body: some View {
        let entries = paddedDays
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            if dynamicTypeSize.isAccessibilitySize {
                LazyVStack(alignment: .leading, spacing: AppSpacing.sm) {
                    ForEach(days) { day in
                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            Text(day.date.formatted(date: .abbreviated, time: .omitted))
                                .font(AppTypography.headline)
                            Label(day.label + (day.isOverride ? ", manually changed" : ""), systemImage: symbol(for: day))
                                .font(AppTypography.callout)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            } else {
                HStack(alignment: .top, spacing: AppSpacing.xs) {
                    VStack(alignment: .leading, spacing: 4) {
                        Color.clear.frame(height: monthLabelHeight)
                        ForEach(0..<7, id: \.self) { index in
                            Text(calendar.shortStandaloneWeekdaySymbols[(index + 1) % 7])
                                .font(AppTypography.caption)
                                .foregroundStyle(Color.ds.textSecondary)
                                .fixedSize(horizontal: true, vertical: false)
                                .frame(height: cellSize)
                        }
                    }
                    .frame(width: weekdayWidth, alignment: .leading)
                    .accessibilityHidden(true)
                    ScrollView(.horizontal) {
                        LazyHStack(alignment: .top, spacing: 4) {
                            ForEach(0..<((entries.count + 6) / 7), id: \.self) { week in
                                weekColumn(week, entries: entries)
                            }
                        }
                    }
                }
            }
            DisclosureGroup("Attendance key") {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), alignment: .leading)], alignment: .leading, spacing: AppSpacing.xs) {
                        legend("Office", "building.2.fill", .ds.officeDay)
                        legend("Home", "house.fill", .ds.homeDay)
                        legend("Mixed", "arrow.left.arrow.right", .ds.accentSecondary)
                        legend("Leave", "leaf", .ds.leaveDay)
                        legend("Holiday", "sparkles", .ds.publicHoliday)
                        legend("Excluded", "minus.circle", .ds.textSecondary)
                        legend("Unrecorded", "questionmark", .ds.textSecondary)
                        legend("Override", "pencil", .ds.warning)
                    }
                    Text("Each square is one day. Faint squares indicate non-working or upcoming days.")
                        .font(AppTypography.caption).foregroundStyle(Color.ds.textSecondary)
                }
                .padding(.top, AppSpacing.xs)
            }
            .font(AppTypography.callout)
            .accessibilityIdentifier("insights.heatmapKey")
        }
        .accessibilityIdentifier("insights.heatmap")
    }

    private func weekColumn(_ week: Int, entries: [AttendanceHeatmapDay?]) -> some View {
        VStack(spacing: 4) {
            let firstIndex = min(week * 7, entries.count - 1)
            let weekDays = entries[firstIndex..<min(firstIndex + 7, entries.count)].compactMap { $0 }
            let monthStart = weekDays.first { calendar.component(.day, from: $0.date) == 1 }
            Text((monthStart ?? (week == 0 ? weekDays.first : nil))?.date.formatted(.dateTime.month(.abbreviated)) ?? "")
                .font(AppTypography.caption).foregroundStyle(Color.ds.textSecondary)
                .fixedSize(horizontal: true, vertical: false)
                .frame(width: cellSize, height: monthLabelHeight, alignment: .leading)
                .accessibilityHidden(true)
            ForEach(0..<7, id: \.self) { weekday in
                let index = week * 7 + weekday
                if index < entries.count, let day = entries[index] {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(color(for: day))
                        .overlay {
                            if day.isOverride {
                                Image(systemName: "pencil").font(.system(size: cellSize * 0.56, weight: .bold))
                                    .foregroundStyle(markColor(for: day))
                            } else if day.classification == .unknown && !day.isUpcoming {
                                Image(systemName: "questionmark").font(.system(size: cellSize / 2, weight: .semibold))
                                    .foregroundStyle(Color.ds.textSecondary)
                            } else if day.classification != .unknown && day.classification != .weekend && day.classification != .nonWorkingDay {
                                Image(systemName: symbol(for: day)).font(.system(size: cellSize / 2, weight: .semibold))
                                    .foregroundStyle(markColor(for: day))
                            }
                        }
                        .frame(width: cellSize, height: cellSize)
                        .accessibilityLabel(day.date.formatted(date: .complete, time: .omitted))
                        .accessibilityValue(day.label + (day.isOverride ? ", manually changed" : ""))
                } else {
                    Color.clear.frame(width: cellSize, height: cellSize).accessibilityHidden(true)
                }
            }
        }
    }

    private func legend(_ label: String, _ symbol: String, _ color: Color) -> some View {
        Label {
            Text(label).foregroundStyle(Color.ds.textSecondary)
        } icon: {
            Image(systemName: symbol).foregroundStyle(color)
        }
        .font(AppTypography.caption)
    }

    private func color(for day: AttendanceHeatmapDay) -> Color {
        if day.isExcluded { return .ds.separator }
        switch day.classification {
        case .office: return .ds.officeDay
        case .home: return .ds.homeDay
        case .mixed: return .ds.accentSecondary
        case .annualLeave, .sickLeave: return .ds.leaveDay.opacity(0.65)
        case .publicHoliday: return .ds.publicHoliday.opacity(0.35)
        case .unknown: return .ds.backgroundSecondary
        case .weekend, .nonWorkingDay: return .ds.backgroundSecondary
        }
    }

    private func markColor(for day: AttendanceHeatmapDay) -> Color {
        if !day.isExcluded && [.office, .home].contains(day.classification) && colorScheme == .light {
            return .white
        }
        if !day.isExcluded && [.office, .home, .mixed].contains(day.classification) {
            return .ds.chartMarkInk
        }
        return .ds.textPrimary
    }

    private func symbol(for day: AttendanceHeatmapDay) -> String {
        if day.isExcluded { return "minus.circle" }
        switch day.classification {
        case .office: return "building.2.fill"
        case .home: return "house.fill"
        case .mixed: return "arrow.left.arrow.right"
        case .annualLeave, .sickLeave: return "leaf"
        case .publicHoliday: return "sparkles"
        case .weekend, .nonWorkingDay: return "calendar"
        case .unknown: return day.isUpcoming ? "clock" : "questionmark.circle"
        }
    }
}
