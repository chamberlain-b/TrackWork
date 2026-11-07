import SwiftUI

struct OfficePlanWeek: Identifiable {
    let start: Date
    let dates: [Date]

    var id: Date {
        start
    }
}

struct OfficePlanWeekBuilder {
    func weeks(
        in range: ComplianceDateRange,
        calendar: Calendar
    ) -> [OfficePlanWeek] {
        let daysBeforeMonth = calendar.mondayBasedWeekdayIndex(for: range.start)
        let firstWeekStart = calendar.date(
            byAdding: .day,
            value: -daysBeforeMonth,
            to: range.start
        ) ?? range.start
        let daysAfterMonth = 6 - calendar.mondayBasedWeekdayIndex(for: range.end)
        let finalWeekEnd = calendar.date(
            byAdding: .day,
            value: daysAfterMonth,
            to: range.end
        ) ?? range.end

        var weeks: [OfficePlanWeek] = []
        var weekStart = firstWeekStart
        while weekStart <= finalWeekEnd {
            let dates = (0..<7).compactMap {
                calendar.date(byAdding: .day, value: $0, to: weekStart)
            }
            weeks.append(OfficePlanWeek(start: weekStart, dates: dates))
            guard let nextWeek = calendar.date(
                byAdding: .day,
                value: 7,
                to: weekStart
            ) else {
                break
            }
            weekStart = nextWeek
        }
        return weeks
    }
}

enum OfficePlanDateState {
    case outsideMonth
    case planned
    case preferred
    case leave
    case holiday
    case excluded
    case completed
    case available
    case unavailable

    var label: String {
        switch self {
        case .outsideMonth:
            "Outside this plan"
        case .planned:
            "Planned"
        case .preferred:
            "Preferred and available"
        case .leave:
            "Leave"
        case .holiday:
            "Public holiday"
        case .excluded:
            "Excluded"
        case .completed:
            "Confirmed office attendance"
        case .available:
            "Available"
        case .unavailable:
            "Not available"
        }
    }

    var isInteractive: Bool {
        switch self {
        case .planned, .preferred, .available:
            true
        case .outsideMonth, .leave, .holiday, .excluded, .completed, .unavailable:
            false
        }
    }
}

struct OfficePlanDayCell: View {
    let date: Date
    let state: OfficePlanDateState
    let isToday: Bool
    let accessibilityIdentifier: String
    let action: (() -> Void)?

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    cellContent
                }
                .buttonStyle(.plain)
            } else {
                cellContent
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            date.formatted(.dateTime.weekday(.wide).day().month(.wide).year())
        )
        .accessibilityValue(state.label)
        .accessibilityHint(state.isInteractive ? "Toggles this office-day reminder" : "")
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var cellContent: some View {
        VStack(spacing: 2) {
            Text(date.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                .font(.caption2.weight(.medium))
                .foregroundStyle(weekdayColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(date.formatted(.dateTime.day()))
                .font(AppTypography.captionStrong.monospacedDigit())
                .foregroundStyle(dayColor)

            OfficePlanStatusMarker(state: state, size: 22)
        }
        .frame(maxWidth: .infinity, minHeight: 52)
        .background {
            if isToday {
                Color.ds.surfaceBlueTint.opacity(0.72)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
        .contentShape(Rectangle())
    }

    private var weekdayColor: Color {
        state == .outsideMonth ? Color.ds.textTertiary : Color.ds.textSecondary
    }

    private var dayColor: Color {
        state == .outsideMonth ? Color.ds.textTertiary : Color.ds.textPrimary
    }
}

struct OfficePlanAgendaDayRow: View {
    let date: Date
    let state: OfficePlanDateState
    let accessibilityIdentifier: String
    let action: (() -> Void)?

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    rowContent
                }
                .buttonStyle(.plain)
            } else {
                rowContent
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            date.formatted(.dateTime.weekday(.wide).day().month(.wide).year())
        )
        .accessibilityValue(state.label)
        .accessibilityHint(state.isInteractive ? "Toggles this office-day reminder" : "")
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var rowContent: some View {
        HStack(spacing: AppSpacing.sm) {
            Text(
                date.formatted(
                    .dateTime.weekday(.wide).day().month(.wide)
                )
            )
            .font(AppTypography.body)
            .foregroundStyle(Color.ds.textPrimary)

            Spacer(minLength: AppSpacing.sm)

            OfficePlanStatusMarker(state: state, size: 28)

            Text(state.label)
                .font(AppTypography.callout)
                .foregroundStyle(Color.ds.textSecondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, AppSpacing.sm)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(
            Color.ds.surfaceSecondary.opacity(0.54),
            in: RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
        )
        .contentShape(Rectangle())
    }
}

struct OfficePlanStatusMarker: View {
    let state: OfficePlanDateState
    let size: CGFloat

    var body: some View {
        ZStack {
            switch state {
            case .planned:
                Circle()
                    .fill(Color.ds.accentPrimary)
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(Color.ds.textInverse)
            case .preferred:
                Circle()
                    .stroke(Color.ds.accentPrimary, lineWidth: 2)
                Image(systemName: "star.fill")
                    .font(.system(size: size * 0.32, weight: .semibold))
                    .foregroundStyle(Color.ds.interactionPrimary)
            case .leave:
                Circle()
                    .fill(Color.ds.leaveDay.opacity(0.14))
                Image(systemName: "sun.max.fill")
                    .font(.system(size: size * 0.46, weight: .semibold))
                    .foregroundStyle(Color.ds.leaveDay)
            case .holiday:
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .fill(Color.ds.publicHoliday.opacity(0.2))
                Image(systemName: "sparkles")
                    .font(.system(size: size * 0.44, weight: .semibold))
                    .foregroundStyle(Color.ds.publicHoliday)
            case .excluded:
                Circle()
                    .stroke(Color.ds.textSecondary, lineWidth: 1.5)
                Image(systemName: "minus")
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(Color.ds.textSecondary)
            case .completed:
                Circle()
                    .fill(Color.ds.success.opacity(0.16))
                Image(systemName: "building.2.fill")
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(Color.ds.success)
            case .available:
                Circle()
                    .stroke(
                        Color.ds.textSecondary,
                        style: StrokeStyle(lineWidth: 1.4, dash: [2.5, 2.5])
                    )
            case .outsideMonth, .unavailable:
                Color.clear
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct OfficePlanLegend: View {
    private let states: [(String, OfficePlanDateState)] = [
        ("Planned", .planned),
        ("Preferred", .preferred),
        ("Leave", .leave),
        ("Holiday", .holiday),
        ("Available", .available)
    ]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppSpacing.xs) {
                ForEach(states, id: \.0) { item in
                    legendItem(title: item.0, state: item.1)
                }
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 92), alignment: .leading)],
                alignment: .leading,
                spacing: AppSpacing.xs
            ) {
                ForEach(states, id: \.0) { item in
                    legendItem(title: item.0, state: item.1)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("officePlan.legend")
    }

    private func legendItem(title: String, state: OfficePlanDateState) -> some View {
        HStack(spacing: 4) {
            OfficePlanStatusMarker(state: state, size: 14)

            Text(title)
                .font(.caption2)
                .foregroundStyle(Color.ds.textSecondary)
                .fixedSize()
        }
    }
}
