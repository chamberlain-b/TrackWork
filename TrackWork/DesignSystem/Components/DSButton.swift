import SwiftUI

enum DSButtonVariant {
    case primary
    case secondary
    case destructive
    case subtle

    var foreground: Color {
        switch self {
        case .primary, .destructive: Color.ds.textInverse
        case .secondary: Color.ds.accentPrimary
        case .subtle: Color.ds.textPrimary
        }
    }

    var background: Color {
        switch self {
        case .primary: Color.ds.accentPrimary
        case .secondary: Color.ds.accentSoft
        case .destructive: Color.ds.critical
        case .subtle: Color.ds.surfaceSecondary
        }
    }

    var border: Color {
        switch self {
        case .primary: Color.ds.accentPrimary.opacity(0.18)
        case .secondary, .subtle: Color.ds.borderSubtle
        case .destructive: Color.ds.critical.opacity(0.18)
        }
    }
}

struct DSButton: View {
    let title: String
    var systemImage: String?
    var variant: DSButtonVariant = .primary
    var isLoading: Bool = false
    var isFullWidth: Bool = true
    var action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                if isLoading {
                    ProgressView()
                        .tint(variant.foreground)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.body.weight(.semibold))
                }

                Text(title)
                    .font(AppTypography.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(variant.foreground)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .frame(minHeight: 50)
            .padding(.horizontal, AppSpacing.lg)
            .background(variant.background.opacity(isEnabled ? 1 : 0.45))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                    .stroke(variant.border, lineWidth: 1)
            }
            .shadow(
                color: Color.ds.accentPrimary.opacity(variant == .primary && isEnabled ? AppShadow.buttonOpacity : 0),
                radius: AppShadow.buttonRadius,
                x: 0,
                y: AppShadow.buttonY
            )
        }
        .disabled(isLoading)
        .animation(AppMotion.quick, value: isLoading)
    }
}
