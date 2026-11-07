import SwiftUI

struct DesignSystemGalleryView: View {
    @State private var selectedTab = "dashboard"

    private let galleryTabs = [
        DSTabItem(id: "dashboard", title: "Home", systemImage: "house.fill"),
        DSTabItem(id: "calendar", title: "Log", systemImage: "calendar"),
        DSTabItem(id: "export", title: "Insights", systemImage: "chart.bar.xaxis"),
        DSTabItem(id: "settings", title: "Settings", systemImage: "gearshape.fill")
    ]

    private let colorSamples: [(String, Color)] = [
        ("Background Primary", .ds.backgroundPrimary),
        ("Surface Primary", .ds.surfacePrimary),
        ("Surface Blue Tint", .ds.surfaceBlueTint),
        ("Text Primary", .ds.textPrimary),
        ("Accent Primary", .ds.accentPrimary),
        ("Success", .ds.success),
        ("Warning", .ds.warning),
        ("Critical", .ds.critical),
        ("Office Day", .ds.officeDay),
        ("Home Day", .ds.homeDay),
        ("Leave Day", .ds.leaveDay),
        ("Separator", .ds.separator)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppSpacing.sectionGap) {
                Text("Design System")
                    .font(AppTypography.screenTitle)
                    .foregroundStyle(Color.ds.textPrimary)

                gallerySection("Colour Tokens") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: AppSpacing.sm)], spacing: AppSpacing.sm) {
                        ForEach(colorSamples, id: \.0) { sample in
                            HStack(spacing: AppSpacing.sm) {
                                Circle()
                                    .fill(sample.1)
                                    .frame(width: 28, height: 28)
                                    .overlay(Circle().stroke(Color.ds.borderSubtle, lineWidth: 1))

                                Text(sample.0)
                                    .font(AppTypography.captionStrong)
                                    .foregroundStyle(Color.ds.textSecondary)
                                    .lineLimit(2)

                                Spacer(minLength: 0)
                            }
                            .padding(AppSpacing.sm)
                            .background(Color.ds.surfacePrimary)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
                        }
                    }
                }

                gallerySection("Typography") {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Screen Title").font(AppTypography.screenTitle)
                        Text("Section Title").font(AppTypography.sectionTitle)
                        Text("Card Title").font(AppTypography.cardTitle)
                        Text("Hero Metric 7 of 12").font(AppTypography.heroMetric.monospacedDigit())
                        Text("Body copy for supporting context.").font(AppTypography.body)
                        Text("Caption Strong").font(AppTypography.captionStrong)
                    }
                    .foregroundStyle(Color.ds.textPrimary)
                }

                gallerySection("Cards") {
                    DSStatusCard(
                        systemImage: "building.2.fill",
                        statusText: "In office",
                        title: "Melbourne HQ",
                        subtitle: "Arrived today at 8:42 AM",
                        trackingStatusText: "Tracking active",
                        lastCheckedText: "2 min ago"
                    )

                    DSProgressCard(
                        sectionTitle: "July progress",
                        metricText: "7 of 12 office days",
                        detailText: "5 still needed · 58% complete",
                        progress: 0.58,
                        statusText: "On track",
                        footerCaption: "Target 12 office days this month"
                    )
                }

                gallerySection("Metric Tiles") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.cardGap) {
                        DSMetricTile(systemImage: "calendar.badge.clock", label: "Workdays left", value: "14", subtitle: "This month", statusColor: Color.ds.info)
                        DSMetricTile(systemImage: "target", label: "Target", value: "12", subtitle: "Office days", statusColor: Color.ds.accentPrimary)
                        DSMetricTile(systemImage: "building.2.fill", label: "Office", value: "58%", subtitle: "7 days", statusColor: Color.ds.officeDay)
                        DSMetricTile(systemImage: "house.fill", label: "Home", value: "33%", subtitle: "4 days", statusColor: Color.ds.homeDay)
                    }
                }

                gallerySection("Editorial metrics") {
                    DSMetricStrip(metrics: [.init(label: "Office days attended", value: "12"),
                                            .init(label: "Office days required", value: "20"),
                                            .init(label: "Office share", value: "60%")])
                    DSAttendanceMix(mix: AttendanceMix(officeDays: 12, homeDays: 6))
                    DSAttendanceMix(mix: AttendanceMix(officeDays: 12, homeDays: 6), usesDonut: true)
                }

                gallerySection("Buttons") {
                    VStack(spacing: AppSpacing.sm) {
                        DSButton(title: "Primary Action", systemImage: "checkmark", variant: .primary, action: {})
                        DSButton(title: "Secondary Action", systemImage: "calendar", variant: .secondary, action: {})
                        DSButton(title: "Subtle Action", systemImage: "ellipsis", variant: .subtle, action: {})
                        DSButton(title: "Delete Record", systemImage: "trash", variant: .destructive, action: {})
                    }
                }

                gallerySection("Status Pills") {
                    FlowLayout(spacing: AppSpacing.xs) {
                        DSStatusPill(text: "Info", systemImage: "info.circle.fill", style: .info)
                        DSStatusPill(text: "Success", systemImage: "checkmark.circle.fill", style: .success)
                        DSStatusPill(text: "Warning", systemImage: "exclamationmark.triangle.fill", style: .warning)
                        DSStatusPill(text: "Critical", systemImage: "xmark.octagon.fill", style: .critical)
                        DSStatusPill(text: "Neutral", style: .neutral)
                    }
                }

                gallerySection("Icon Badges") {
                    HStack(spacing: AppSpacing.sm) {
                        DSIconBadge(systemImage: "sparkles", style: .accent)
                        DSIconBadge(systemImage: "checkmark", style: .success)
                        DSIconBadge(systemImage: "building.2.fill", style: .office)
                        DSIconBadge(systemImage: "house.fill", style: .home)
                        DSIconBadge(systemImage: "leaf.fill", style: .leave)
                    }
                }

                gallerySection("Callout") {
                    DSInsightCallout(
                        icon: "lightbulb.fill",
                        message: "Plan two more office days this week to keep July on track."
                    )
                }

                gallerySection("Tab Bar") {
                    TabView(selection: $selectedTab) {
                        ForEach(galleryTabs) { item in
                            Tab(item.title, systemImage: item.systemImage, value: item.id) {
                                Text(item.title).appScreenBackground()
                            }
                        }
                    }
                    .frame(height: 180)
                }

                gallerySection("Empty State") {
                    DSEmptyState(
                        systemImage: "calendar.badge.exclamationmark",
                        title: "No records yet",
                        message: "Attendance records will appear once tracking begins.",
                        actionTitle: "Add Record",
                        actionSystemImage: "plus",
                        action: {}
                    )
                }
            }
            .padding(AppSpacing.screenHorizontal)
        }
        .appScreenBackground()
    }

    private func gallerySection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.sectionTitle)
                .foregroundStyle(Color.ds.textPrimary)

            content()
        }
    }
}

private struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    let content: Content

    init(spacing: CGFloat, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: spacing) {
                content
            }

            VStack(alignment: .leading, spacing: spacing) {
                content
            }
        }
    }
}

#Preview("Light") {
    DesignSystemGalleryView()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    DesignSystemGalleryView()
        .preferredColorScheme(.dark)
}

#Preview("Large Text") {
    DesignSystemGalleryView()
        .environment(\.sizeCategory, .accessibilityLarge)
}

#Preview("Maximum text") {
    DesignSystemGalleryView()
        .dynamicTypeSize(.accessibility5)
}
