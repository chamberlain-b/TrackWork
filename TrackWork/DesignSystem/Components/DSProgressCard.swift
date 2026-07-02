import SwiftUI

struct DSProgressCard: View {
    let sectionTitle: String
    let metricText: String
    let detailText: String
    let progress: Double
    var statusText: String?
    var statusStyle: DSStatusPillStyle = .success
    var footerCaption: String?

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            HStack(alignment: .top) {
                Text(sectionTitle)
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(Color.ds.textSecondary)

                Spacer(minLength: AppSpacing.sm)

                if let statusText {
                    DSStatusPill(text: statusText, style: statusStyle)
                }
            }

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(metricText)
                    .font(AppTypography.heroMetric.monospacedDigit())
                    .foregroundStyle(Color.ds.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                HStack(alignment: .firstTextBaseline) {
                    Text(detailText)
                        .font(AppTypography.callout.monospacedDigit())
                        .foregroundStyle(Color.ds.textSecondary)

                    Spacer(minLength: AppSpacing.sm)

                    Text(clampedProgress.formatted(.percent.precision(.fractionLength(0))))
                        .font(AppTypography.captionStrong.monospacedDigit())
                        .foregroundStyle(Color.ds.accentPrimary)
                }
            }

            ProgressView(value: clampedProgress)
                .tint(Color.ds.accentPrimary)
                .background(Color.ds.accentMuted.opacity(0.28), in: Capsule())
                .scaleEffect(x: 1, y: 1.8, anchor: .center)

            if let footerCaption {
                Text(footerCaption)
                    .font(AppTypography.caption)
                    .foregroundStyle(Color.ds.textTertiary)
            }
        }
        .padding(AppSpacing.lg)
        .background(Color.ds.surfaceBlueTint)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.heroCard, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.heroCard, style: .continuous)
                .stroke(Color.ds.borderSubtle, lineWidth: 1)
        }
        .shadow(color: Color.ds.shadowTint.opacity(AppShadow.cardOpacity), radius: AppShadow.cardRadius, x: 0, y: AppShadow.cardY)
    }
}
