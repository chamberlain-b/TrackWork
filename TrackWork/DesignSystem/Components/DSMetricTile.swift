import SwiftUI

struct DSMetricTile: View {
    let systemImage: String
    let label: String
    let value: String
    var subtitle: String?
    var statusColor: Color = Color.ds.accentPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(statusColor)
                    .frame(width: 30, height: 30)
                    .background(statusColor.opacity(0.1), in: Circle())
                    .accessibilityHidden(true)

                Spacer(minLength: AppSpacing.xs)
            }

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(label)
                    .font(AppTypography.captionStrong)
                    .foregroundStyle(Color.ds.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(value)
                    .font(AppTypography.smallMetric.monospacedDigit())
                    .foregroundStyle(Color.ds.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle {
                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundStyle(Color.ds.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ds.surfaceSecondary.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .stroke(Color.ds.borderSubtle.opacity(0.62), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(accessibilityValue))
    }

    private var accessibilityValue: String {
        [value, subtitle]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}
