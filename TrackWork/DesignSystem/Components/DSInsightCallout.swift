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
                .frame(width: 28, height: 28)
                .background(Color.ds.info.opacity(0.12))
                .clipShape(Circle())

            if let highlightedText {
                Text("\(Text(message)) \(Text(highlightedText).fontWeight(.semibold))")
            } else {
                Text(message)
            }
        }
        .font(AppTypography.callout)
        .foregroundStyle(Color.ds.textSecondary)
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ds.info.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .stroke(Color.ds.info.opacity(0.14), lineWidth: 1)
        }
    }
}
