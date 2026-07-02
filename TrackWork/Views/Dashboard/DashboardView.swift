import SwiftUI

struct DashboardView: View {
    private let columns = [
        GridItem(.flexible(), spacing: AppSpacing.cardGap),
        GridItem(.flexible(), spacing: AppSpacing.cardGap)
    ]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.sectionGap) {
                    header

                    DSStatusCard(
                        systemImage: "building.2.fill",
                        statusText: "In office",
                        title: "Melbourne HQ",
                        subtitle: "Arrived today at 8:42 AM",
                        trackingStatusText: "Tracking active",
                        lastCheckedText: "2 min ago",
                        statusStyle: .success,
                        iconStyle: .office
                    )

                    DSProgressCard(
                        sectionTitle: "July progress",
                        metricText: "7 of 12 office days",
                        detailText: "5 still needed · 58% complete",
                        progress: 0.58,
                        statusText: "On track",
                        statusStyle: .success,
                        footerCaption: "Target 12 office days this month"
                    )

                    monthOutlookCard
                    reviewCard
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xxl)
            }
            .appScreenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("Today")
                    .font(AppTypography.screenTitle)
                    .foregroundStyle(Color.ds.textPrimary)

                Text("Thursday, 2 July")
                    .font(AppTypography.callout.monospacedDigit())
                    .foregroundStyle(Color.ds.textSecondary)
            }

            Spacer()

            Button {
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.headline)
                    .foregroundStyle(Color.ds.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(Color.ds.surfaceGlass)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(Color.ds.borderSubtle, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
    }

    private var monthOutlookCard: some View {
        DSCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Month outlook")
                    .font(AppTypography.sectionTitle)
                    .foregroundStyle(Color.ds.textPrimary)

                LazyVGrid(columns: columns, spacing: AppSpacing.cardGap) {
                    DSMetricTile(systemImage: "calendar.badge.clock", label: "Workdays left", value: "14", subtitle: "This month", statusColor: Color.ds.info)
                    DSMetricTile(systemImage: "target", label: "Attendance target", value: "12", subtitle: "Office days", statusColor: Color.ds.accentPrimary)
                    DSMetricTile(systemImage: "building.2.fill", label: "Office %", value: "58%", subtitle: "7 days", statusColor: Color.ds.officeDay)
                    DSMetricTile(systemImage: "house.fill", label: "Home %", value: "33%", subtitle: "4 days", statusColor: Color.ds.homeDay)
                }

                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color.ds.leaveDay)
                    Text("Leave is tracking at 8% of recorded workdays")
                        .font(AppTypography.caption.monospacedDigit())
                        .foregroundStyle(Color.ds.textSecondary)
                    Spacer(minLength: 0)
                }
                .padding(.top, AppSpacing.xxs)

                DSInsightCallout(
                    icon: "lightbulb.fill",
                    message: "You need 5 more office days to stay comfortably aligned with July’s attendance target."
                )
            }
        }
    }

    private var reviewCard: some View {
        DSCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(spacing: AppSpacing.sm) {
                    DSIconBadge(systemImage: "checkmark.seal.fill", style: .success, size: 42)

                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text("Today’s record is ready to review")
                            .font(AppTypography.cardTitle)
                            .foregroundStyle(Color.ds.textPrimary)

                        Text("Confirm the automatic attendance record before export.")
                            .font(AppTypography.callout)
                            .foregroundStyle(Color.ds.textSecondary)
                    }
                }

                DSButton(title: "Correct Today’s Record", systemImage: "pencil", action: {})
            }
        }
    }
}

#Preview {
    DashboardView()
}
