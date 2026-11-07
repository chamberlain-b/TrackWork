import SwiftUI

extension OfficePlanView {
    var referenceDateMenu: some View {
        Menu {
            Button {
                moveMonth(by: -1)
            } label: {
                Label("Previous month", systemImage: "chevron.left")
            }
            .accessibilityIdentifier("officePlan.previousMonth")

            Button {
                showReferenceMonth()
            } label: {
                Label(
                    referenceDate.formatted(.dateTime.month(.wide).year()),
                    systemImage: "calendar"
                )
            }
            .accessibilityIdentifier("officePlan.referenceMonth")

            Button {
                moveMonth(by: 1)
            } label: {
                Label("Next month", systemImage: "chevron.right")
            }
            .accessibilityIdentifier("officePlan.nextMonth")
        } label: {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "calendar")
                    .accessibilityHidden(true)

                Text(
                    referenceDate.formatted(
                        .dateTime.weekday(.wide).day().month(.wide).year()
                    )
                )
                .font(AppTypography.callout.weight(.medium))

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(Color.ds.interactionPrimary)
            .padding(.horizontal, AppSpacing.md)
            .frame(minHeight: 44)
            .background(
                Color.ds.surfacePrimary.opacity(0.72),
                in: Capsule(style: .continuous)
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(Color.ds.borderSubtle.opacity(0.82), lineWidth: 1)
            }
        }
        .accessibilityLabel(
            "Planning options as of \(referenceDate.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))"
        )
        .accessibilityIdentifier("officePlan.referenceDate")
    }

    var planSurface: some View {
        let data = planData

        return VStack(alignment: .leading, spacing: 0) {
            planHeader(data)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)

            Divider()

            if usesAccessibilityAgenda {
                planActions(data)
                    .padding(AppSpacing.md)

                Divider()
            }

            ForEach(Array(data.calendarWeeks.enumerated()), id: \.element.id) { index, week in
                weekSection(week, index: index + 1, data: data)

                if week.id != data.calendarWeeks.last?.id {
                    Divider()
                }
            }

            if !usesAccessibilityAgenda {
                Divider()

                planActions(data)
                    .padding(AppSpacing.md)
            }
        }
        .cardSurface()
    }

    func planHeader(_ data: OfficePlanViewDataSnapshot) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    monthHeading(data)
                    Spacer(minLength: AppSpacing.xs)
                    planStatus(data)
                }

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    monthHeading(data)
                    planStatus(data)
                }
            }

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                        plannedProgressLabel(data)
                        Spacer(minLength: AppSpacing.xs)
                        additionalPlansLabel(data)
                    }

                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        plannedProgressLabel(data)
                        additionalPlansLabel(data)
                    }
                }

                ProgressView(
                    value: planProgressValue(data),
                    total: planProgressTotal(data)
                )
                .tint(planAccentColor(data))
                .background(Color.ds.accentMuted.opacity(0.2), in: Capsule())
                .scaleEffect(x: 1, y: 1.4, anchor: .center)
                .accessibilityLabel("Office plan progress")
                .accessibilityValue(progressAccessibilityValue(data))
                .accessibilityIdentifier("officePlan.progress")
            }

            OfficePlanLegend()

            if data.summary.reviewRequiredDays > 0 {
                Label(reviewRequiredMessage(data), systemImage: "exclamationmark.triangle.fill")
                    .font(AppTypography.caption)
                    .foregroundStyle(Color.ds.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if data.remainingOfficeDays > data.candidateDates.count {
                Label(unreachableTargetMessage(data), systemImage: "exclamationmark.triangle.fill")
                    .font(AppTypography.caption)
                    .foregroundStyle(Color.ds.critical)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    func monthHeading(_ data: OfficePlanViewDataSnapshot) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text("\(monthTitle(data)) plan")
                .font(AppTypography.cardTitle)
                .foregroundStyle(Color.ds.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("officePlan.monthTitle")

            Text("Target: \(data.summary.requiredOfficeDays) office days")
                .font(AppTypography.callout)
                .foregroundStyle(Color.ds.textSecondary)
        }
    }

    func planStatus(_ data: OfficePlanViewDataSnapshot) -> some View {
        DSStatusPill(
            text: planStatusText(data),
            systemImage: planStatusSystemImage(data),
            style: planStatusStyle(data)
        )
        .accessibilityIdentifier("officePlan.status")
    }

    func plannedProgressLabel(_ data: OfficePlanViewDataSnapshot) -> some View {
        Text(progressLabelText(data))
            .font(AppTypography.callout)
            .foregroundStyle(Color.ds.textSecondary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Office days planned")
            .accessibilityValue(data.plannedCandidateDays.formatted())
            .accessibilityIdentifier("officePlan.planned")
    }

    func additionalPlansLabel(_ data: OfficePlanViewDataSnapshot) -> some View {
        Text(additionalPlansText(data))
            .font(AppTypography.callout)
            .foregroundStyle(Color.ds.textSecondary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Additional office days needed")
            .accessibilityValue(data.additionalPlansNeeded.formatted())
            .accessibilityIdentifier("officePlan.needed")
    }

    func weekSection(
        _ week: OfficePlanWeek,
        index: Int,
        data: OfficePlanViewDataSnapshot
    ) -> some View {
        let isCollapsed = isWeekCollapsed(week)
        return VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            weekHeader(week, index: index, isCollapsed: isCollapsed, data: data)

            if !isCollapsed {
                weekContent(week, data: data)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xs)
    }

    func weekHeader(
        _ week: OfficePlanWeek,
        index: Int,
        isCollapsed: Bool,
        data: OfficePlanViewDataSnapshot
    ) -> some View {
        Button {
            toggleWeek(week)
        } label: {
            HStack(spacing: AppSpacing.xs) {
                Text("WEEK \(index) • \(weekRangeText(week))")
                    .font(AppTypography.captionStrong)
                    .foregroundStyle(Color.ds.textSecondary)

                Spacer(minLength: AppSpacing.xs)

                Text(weekPlanText(week, in: data))
                    .font(AppTypography.callout.monospacedDigit())
                    .foregroundStyle(Color.ds.textSecondary)

                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.ds.textTertiary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Week \(index), \(weekRangeAccessibilityText(week))")
        .accessibilityValue(
            "\(weekPlanText(week, in: data)), \(isCollapsed ? "Collapsed" : "Expanded")"
        )
        .accessibilityHint(isCollapsed ? "Expands this week" : "Collapses this week")
        .accessibilityIdentifier(
            usesAccessibilityAgenda
                ? "officePlan.accessibilityAgenda.\(isoDateString(for: week.start))"
                : weekIdentifier(for: week)
        )
    }

    @ViewBuilder
    func weekContent(_ week: OfficePlanWeek, data: OfficePlanViewDataSnapshot) -> some View {
        if usesAccessibilityAgenda {
            weekAgenda(week, data: data)
        } else {
            ViewThatFits(in: .horizontal) {
                weekGrid(week, data: data)
                weekAgenda(week, data: data)
            }
        }
    }

    func weekGrid(_ week: OfficePlanWeek, data: OfficePlanViewDataSnapshot) -> some View {
        HStack(spacing: 2) {
            ForEach(week.dates, id: \.self) { date in
                OfficePlanDayCell(
                    date: date,
                    state: dateState(for: date, in: data),
                    isToday: calendar.isDate(date, inSameDayAs: referenceDate),
                    accessibilityIdentifier: dayIdentifier(for: date),
                    action: dayAction(for: date, in: data)
                )
                .frame(minWidth: 44)
            }
        }
    }

    func weekAgenda(_ week: OfficePlanWeek, data: OfficePlanViewDataSnapshot) -> some View {
        VStack(spacing: AppSpacing.xxs) {
            ForEach(week.dates.filter { isInDisplayedMonth($0, in: data) }, id: \.self) { date in
                OfficePlanAgendaDayRow(
                    date: date,
                    state: dateState(for: date, in: data),
                    accessibilityIdentifier: dayIdentifier(for: date),
                    action: dayAction(for: date, in: data)
                )
            }
        }
    }

    func planActions(_ data: OfficePlanViewDataSnapshot) -> some View {
        VStack(spacing: AppSpacing.sm) {
            DSButton(
                title: suggestButtonTitle(data),
                systemImage: "wand.and.stars",
                action: suggestPlan
            )
            .disabled(
                data.additionalPlansNeeded == 0 ||
                    data.unselectedCandidateDates.isEmpty
            )
            .accessibilityIdentifier("officePlan.suggest")

            if !data.invalidSelectedDates.isEmpty {
                Button(action: requestUnavailablePlanRemoval) {
                    Label(
                        removeUnavailablePlansTitle(data),
                        systemImage: "calendar.badge.minus"
                    )
                    .font(AppTypography.headline)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.ds.critical)
                .accessibilityHint("Removes reminders that are no longer eligible workdays")
                .accessibilityIdentifier("officePlan.removeUnavailable")
            }

            Button(action: requestReplan) {
                Label("Re-plan month", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                    .font(AppTypography.headline)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.ds.interactionPrimary)
            .disabled(data.remainingOfficeDays == 0 || data.candidateDates.isEmpty)
            .accessibilityHint("Replaces this month’s reminders after confirmation")
            .accessibilityIdentifier("officePlan.replan")

            Text("Plans are reminders for you and won’t mark attendance.")
                .font(AppTypography.caption)
                .foregroundStyle(Color.ds.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
