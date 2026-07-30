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
            .foregroundStyle(Color.ds.accentPrimary)
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
        VStack(alignment: .leading, spacing: 0) {
            planHeader
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)

            Divider()

            if usesAccessibilityAgenda {
                planActions
                    .padding(AppSpacing.md)

                Divider()
            }

            ForEach(Array(calendarWeeks.enumerated()), id: \.element.id) { index, week in
                weekSection(week, index: index + 1)

                if week.id != calendarWeeks.last?.id {
                    Divider()
                }
            }

            if !usesAccessibilityAgenda {
                Divider()

                planActions
                    .padding(AppSpacing.md)
            }
        }
        .background(.regularMaterial)
        .background(Color.ds.surfacePrimary.opacity(0.74))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.heroCard, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.heroCard, style: .continuous)
                .strokeBorder(Color.ds.borderSubtle.opacity(0.72), lineWidth: 0.8)
        }
        .shadow(
            color: Color.ds.shadowTint.opacity(AppShadow.cardOpacity * 0.55),
            radius: AppShadow.cardRadius * 0.75,
            x: 0,
            y: AppShadow.cardY * 0.7
        )
    }

    var planHeader: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    monthHeading
                    Spacer(minLength: AppSpacing.xs)
                    planStatus
                }

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    monthHeading
                    planStatus
                }
            }

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                        plannedProgressLabel
                        Spacer(minLength: AppSpacing.xs)
                        additionalPlansLabel
                    }

                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        plannedProgressLabel
                        additionalPlansLabel
                    }
                }

                ProgressView(
                    value: planProgressValue,
                    total: planProgressTotal
                )
                .tint(planAccentColor)
                .background(Color.ds.accentMuted.opacity(0.2), in: Capsule())
                .scaleEffect(x: 1, y: 1.4, anchor: .center)
                .accessibilityLabel("Office plan progress")
                .accessibilityValue(progressAccessibilityValue)
                .accessibilityIdentifier("officePlan.progress")
            }

            OfficePlanLegend()

            if summary.reviewRequiredDays > 0 {
                Label(reviewRequiredMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(AppTypography.caption)
                    .foregroundStyle(Color.ds.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if remainingOfficeDays > candidateDates.count {
                Label(unreachableTargetMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(AppTypography.caption)
                    .foregroundStyle(Color.ds.critical)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    var monthHeading: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text("\(monthTitle) plan")
                .font(AppTypography.cardTitle)
                .foregroundStyle(Color.ds.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("officePlan.monthTitle")

            Text("Target: \(summary.requiredOfficeDays) office days")
                .font(AppTypography.callout)
                .foregroundStyle(Color.ds.textSecondary)
        }
    }

    var planStatus: some View {
        DSStatusPill(
            text: planStatusText,
            systemImage: planStatusSystemImage,
            style: planStatusStyle
        )
        .accessibilityIdentifier("officePlan.status")
    }

    var plannedProgressLabel: some View {
        Text(progressLabelText)
            .font(AppTypography.callout)
            .foregroundStyle(Color.ds.textSecondary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Office days planned")
            .accessibilityValue(plannedCandidateDays.formatted())
            .accessibilityIdentifier("officePlan.planned")
    }

    var additionalPlansLabel: some View {
        Text(additionalPlansText)
            .font(AppTypography.callout)
            .foregroundStyle(Color.ds.textSecondary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Additional office days needed")
            .accessibilityValue(additionalPlansNeeded.formatted())
            .accessibilityIdentifier("officePlan.needed")
    }

    func weekSection(_ week: OfficePlanWeek, index: Int) -> some View {
        let isCollapsed = isWeekCollapsed(week)
        return VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            weekHeader(week, index: index, isCollapsed: isCollapsed)

            if !isCollapsed {
                weekContent(week)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xs)
    }

    func weekHeader(
        _ week: OfficePlanWeek,
        index: Int,
        isCollapsed: Bool
    ) -> some View {
        Button {
            toggleWeek(week)
        } label: {
            HStack(spacing: AppSpacing.xs) {
                Text("WEEK \(index) • \(weekRangeText(week))")
                    .font(AppTypography.captionStrong)
                    .foregroundStyle(Color.ds.textSecondary)

                Spacer(minLength: AppSpacing.xs)

                Text(weekPlanText(week))
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
            "\(weekPlanText(week)), \(isCollapsed ? "Collapsed" : "Expanded")"
        )
        .accessibilityHint(isCollapsed ? "Expands this week" : "Collapses this week")
        .accessibilityIdentifier(
            usesAccessibilityAgenda
                ? "officePlan.accessibilityAgenda.\(isoDateString(for: week.start))"
                : weekIdentifier(for: week)
        )
    }

    @ViewBuilder
    func weekContent(_ week: OfficePlanWeek) -> some View {
        if usesAccessibilityAgenda {
            weekAgenda(week)
        } else {
            ViewThatFits(in: .horizontal) {
                weekGrid(week)
                weekAgenda(week)
            }
        }
    }

    func weekGrid(_ week: OfficePlanWeek) -> some View {
        HStack(spacing: 2) {
            ForEach(week.dates, id: \.self) { date in
                OfficePlanDayCell(
                    date: date,
                    state: dateState(for: date),
                    isToday: calendar.isDate(date, inSameDayAs: referenceDate),
                    accessibilityIdentifier: dayIdentifier(for: date),
                    action: dayAction(for: date)
                )
                .frame(minWidth: 44)
            }
        }
    }

    func weekAgenda(_ week: OfficePlanWeek) -> some View {
        VStack(spacing: AppSpacing.xxs) {
            ForEach(week.dates.filter(isInDisplayedMonth), id: \.self) { date in
                OfficePlanAgendaDayRow(
                    date: date,
                    state: dateState(for: date),
                    accessibilityIdentifier: dayIdentifier(for: date),
                    action: dayAction(for: date)
                )
            }
        }
    }

    var planActions: some View {
        VStack(spacing: AppSpacing.sm) {
            DSButton(
                title: suggestButtonTitle,
                systemImage: "wand.and.stars",
                action: suggestPlan
            )
            .disabled(
                additionalPlansNeeded == 0 ||
                    unselectedCandidateDates.isEmpty
            )
            .accessibilityIdentifier("officePlan.suggest")

            if !invalidSelectedDates.isEmpty {
                Button(action: requestUnavailablePlanRemoval) {
                    Label(
                        removeUnavailablePlansTitle,
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
            .foregroundStyle(Color.ds.accentPrimary)
            .disabled(remainingOfficeDays == 0 || candidateDates.isEmpty)
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
