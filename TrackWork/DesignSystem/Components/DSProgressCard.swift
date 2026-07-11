import SwiftUI

struct DSProgressCard: View {
    let sectionTitle: String
    let metricText: String
    let detailText: String
    let progress: Double
    var statusText: String?
    var statusSystemImage: String?
    var statusStyle: DSStatusPillStyle = .success
    var footerCaption: String?
    var showsProgress = true
    var progressTint: Color = Color.ds.accentPrimary
    var progressAccessibilityLabel: String?
    var progressAccessibilityValue: String?

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            summary

            if showsProgress {
                ProgressView(value: clampedProgress)
                    .tint(progressTint)
                    .background(Color.ds.accentMuted.opacity(0.28), in: Capsule())
                    .scaleEffect(x: 1, y: 1.8, anchor: .center)
                    .accessibilityLabel(progressAccessibilityLabel ?? "\(sectionTitle) progress")
                    .accessibilityValue(progressAccessibilityValue ?? formattedProgress)
            }

            if let footerCaption {
                Text(footerCaption)
                    .font(AppTypography.caption)
                    .foregroundStyle(Color.ds.textSecondary)
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

    private var summary: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top) {
                    sectionHeading
                    Spacer(minLength: AppSpacing.sm)
                    statusPill
                }

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    sectionHeading
                    statusPill
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

                    if showsProgress {
                        Text(formattedProgress)
                            .font(AppTypography.captionStrong.monospacedDigit())
                            .foregroundStyle(progressTint)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(sectionTitle)
        .accessibilityValue(summaryAccessibilityValue)
        .accessibilityAddTraits(.isHeader)
    }

    private var sectionHeading: some View {
        Text(sectionTitle)
            .font(AppTypography.cardTitle)
            .foregroundStyle(Color.ds.textSecondary)
    }

    @ViewBuilder
    private var statusPill: some View {
        if let statusText {
            DSStatusPill(text: statusText, systemImage: statusSystemImage, style: statusStyle)
        }
    }

    private var formattedProgress: String {
        clampedProgress.formatted(.percent.precision(.fractionLength(0)))
    }

    private var summaryAccessibilityValue: String {
        [metricText, detailText, statusText]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}
