import SwiftUI

struct DSStatusCard: View {
    let systemImage: String
    let statusText: String
    let title: String
    let subtitle: String
    let trackingStatusText: String
    let lastCheckedText: String
    var statusStyle: DSStatusPillStyle = .success
    var iconStyle: DSIconBadgeStyle = .office

    var body: some View {
        DSCard {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                DSIconBadge(systemImage: systemImage, style: iconStyle, size: 62)

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    DSStatusPill(text: statusText, systemImage: "checkmark.circle.fill", style: statusStyle)

                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text(title)
                            .font(AppTypography.cardTitle)
                            .foregroundStyle(Color.ds.textPrimary)
                            .lineLimit(2)

                        Text(subtitle)
                            .font(AppTypography.callout.monospacedDigit())
                            .foregroundStyle(Color.ds.textSecondary)
                            .lineLimit(2)
                    }

                    Divider()
                        .overlay(Color.ds.separator)

                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "location.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.ds.success)

                        Text(trackingStatusText)
                            .font(AppTypography.captionStrong)
                            .foregroundStyle(Color.ds.textSecondary)

                        Spacer(minLength: AppSpacing.xs)

                        Text(lastCheckedText)
                            .font(AppTypography.caption.monospacedDigit())
                            .foregroundStyle(Color.ds.textTertiary)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
