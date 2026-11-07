import SwiftUI

struct CalendarPrimaryToolbar: ToolbarContent {
    let displayedMonth: Date
    let referenceDate: Date
    @Binding var isShowingBatchLeave: Bool
    @Binding var isShowingLegend: Bool

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                isShowingLegend = true
            } label: {
                Label("Legend", systemImage: "info.circle")
            }
            .accessibilityIdentifier("calendar.legend")

            Menu {
                NavigationLink {
                    OfficePlanView(
                        displayedMonth: displayedMonth,
                        referenceDate: referenceDate
                    )
                } label: {
                    Label("Plan Office Days", systemImage: "calendar.badge.clock")
                }
                .accessibilityIdentifier("calendar.officePlan")

                Button {
                    isShowingBatchLeave = true
                } label: {
                    Label("Add Leave", systemImage: "calendar.badge.plus")
                }
                .accessibilityHint("Opens batch leave entry for this month")
                .accessibilityIdentifier("calendar.addLeave")
            } label: {
                Label("Add", systemImage: "plus")
            }
            .accessibilityIdentifier("calendar.actions")
        }
    }
}

struct CalendarLegendGrid: View {
    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 100), spacing: AppSpacing.xs)],
            spacing: AppSpacing.xs
        ) {
            LegendPill(text: "Office", systemImage: "building.2.fill", color: Color.ds.officeDay)
            LegendPill(text: "Home", systemImage: "house.fill", color: Color.ds.homeDay)
            LegendPill(text: "Mixed", systemImage: "arrow.left.arrow.right", color: Color.ds.info)
            LegendPill(text: "Annual leave", systemImage: "sun.max.fill", color: Color.ds.leaveDay)
            LegendPill(text: "Sick leave", systemImage: "cross.case.fill", color: Color.ds.leaveDay)
            LegendPill(text: "Holiday", systemImage: "sparkles", color: Color.ds.publicHoliday)
            LegendPill(text: "Excluded", systemImage: "calendar.badge.minus", color: Color.ds.textSecondary)
            LegendPill(text: "Planned", systemImage: "calendar.badge.clock", color: Color.ds.accentPrimary)
            LegendPill(text: "Needs review", systemImage: "circle.fill", color: Color.ds.warning)
        }
    }
}
