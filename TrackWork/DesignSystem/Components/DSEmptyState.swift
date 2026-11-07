import SwiftUI

struct DSEmptyState: View {
    var systemImage: String?
    let title: String
    let message: String
    var actionTitle: String?
    var actionSystemImage: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            if let systemImage {
                DSIconBadge(systemImage: systemImage, style: .accent, size: 32)
            }

            VStack(spacing: AppSpacing.xs) {
                Text(title)
                    .font(AppTypography.title)
                    .foregroundStyle(Color.ds.textPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(AppTypography.body)
                    .foregroundStyle(Color.ds.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let actionTitle, let action {
                DSButton(
                    title: actionTitle,
                    systemImage: actionSystemImage,
                    variant: .secondary,
                    isFullWidth: false,
                    action: action
                )
            }
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity)
        .cardSurface(includesShadow: false)
    }
}
