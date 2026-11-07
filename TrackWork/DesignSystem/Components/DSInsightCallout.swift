import SwiftUI

struct DSInsightCallout: View {
    let icon: String
    let message: String
    var highlightedText: String?

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.ds.info)
                .frame(width: 30, height: 30)
                .background(Color.ds.info.opacity(0.1), in: Circle())

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                if let highlightedText {
                    Text(highlightedText)
                        .font(AppTypography.captionStrong)
                        .foregroundStyle(Color.ds.textPrimary)
                }

                Text(message)
                    .font(AppTypography.callout)
                    .foregroundStyle(Color.ds.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ds.surfaceSecondary, in: RoundedRectangle(cornerRadius: AppRadius.lg))
    }
}
