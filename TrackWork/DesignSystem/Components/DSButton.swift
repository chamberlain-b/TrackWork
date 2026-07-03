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
        case .secondary: Color.ds.accentSoft.opacity(0.82)
        case .destructive: Color.ds.critical
        case .subtle: Color.ds.surfaceSecondary.opacity(0.72)
        }
    }

    var border: Color {
        switch self {
        case .primary: Color.ds.accentPrimary.opacity(0.2)
        case .secondary: Color.ds.accentPrimary.opacity(0.18)
        case .subtle: Color.ds.borderSubtle.opacity(0.72)
        case .destructive: Color.ds.critical.opacity(0.2)
        }
    }

    var glassTint: Color {
        switch self {
        case .primary, .secondary: Color.ds.accentPrimary
        case .destructive: Color.ds.critical
        case .subtle: Color.ds.surfaceGlass
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
            .foregroundStyle(variant.foreground.opacity(isEnabled ? 1 : 0.65))
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .frame(minHeight: 50)
            .padding(.horizontal, AppSpacing.lg)
            .background(variant.background.opacity(isEnabled ? 1 : 0.45))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                    .stroke(variant.border, lineWidth: 1)
            }
            .glassSurface(cornerRadius: AppRadius.button, tint: variant.glassTint, isInteractive: true)
            .shadow(
                color: Color.ds.accentPrimary.opacity(variant == .primary && isEnabled ? AppShadow.buttonOpacity * 0.55 : 0),
                radius: AppShadow.buttonRadius * 0.8,
                x: 0,
                y: AppShadow.buttonY * 0.8
            )
        }
        .disabled(isLoading)
        .animation(AppMotion.quick, value: isLoading)
    }
}
