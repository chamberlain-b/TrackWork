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
    var showsProgressPercentage = true
    var progressMetricTitle: String?
    var progressTint: Color = Color.ds.accentPrimary
    var progressAccessibilityLabel: String?
    var progressAccessibilityValue: String?

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            summary

            if showsProgress {
                ProgressView(value: clampedProgress)
                    .tint(progressTint)
                    .background(Color.ds.accentMuted.opacity(0.22), in: Capsule())
                    .scaleEffect(x: 1, y: 1.55, anchor: .center)
                    .accessibilityLabel(progressAccessibilityLabel ?? "\(sectionTitle) progress")
                    .accessibilityValue(progressAccessibilityValue ?? formattedProgress)
            }

            if let footerCaption {
                Label(footerCaption, systemImage: "calendar")
                    .font(AppTypography.caption.monospacedDigit())
                    .foregroundStyle(Color.ds.textSecondary)
                    .labelStyle(.titleAndIcon)
            }
        }

    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
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

            metricSummary
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(sectionTitle)
        .accessibilityValue(summaryAccessibilityValue)
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var metricSummary: some View {
        if let progressMetricTitle, showsProgress {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .bottom, spacing: AppSpacing.lg) {
                    primaryMetric
                        .frame(maxWidth: .infinity, alignment: .leading)

                    progressMetric(title: progressMetricTitle)
                }

                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    primaryMetric
                    progressMetric(title: progressMetricTitle)
                }
            }
        } else {
            primaryMetric
        }
    }

    private var primaryMetric: some View {
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

                if showsProgress && showsProgressPercentage && progressMetricTitle == nil {
                    Text(formattedProgress)
                        .font(AppTypography.captionStrong.monospacedDigit())
                        .foregroundStyle(progressTint)
                }
            }
        }
    }

    private func progressMetric(title: String) -> some View {
        VStack(alignment: .trailing, spacing: AppSpacing.xxs) {
            Text(formattedProgress)
                .font(AppTypography.title.monospacedDigit())
                .foregroundStyle(progressTint)

            Text(title)
                .font(AppTypography.captionStrong)
                .foregroundStyle(Color.ds.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(formattedProgress)
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

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: AppRadius.heroCard, style: .continuous)
    }

    private var summaryAccessibilityValue: String {
        [
            metricText,
            detailText,
            progressMetricTitle.map { "\(formattedProgress) \($0)" },
            statusText
        ]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}
