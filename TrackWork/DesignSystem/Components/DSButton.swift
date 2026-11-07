import SwiftUI

enum DSButtonVariant {
    case primary
    case secondary
    case destructive
    case subtle

    var foreground: Color {
        switch self {
        case .primary: Color.ds.textInverse
        case .destructive: Color.ds.textInverse
        case .secondary: Color.ds.interactionPrimary
        case .subtle: Color.ds.textPrimary
        }
    }

    var background: Color {
        switch self {
        case .primary: Color.ds.interactionPrimary
        case .secondary: Color.ds.accentSoft.opacity(0.82)
        case .destructive: Color.ds.critical
        case .subtle: Color.ds.surfaceSecondary.opacity(0.72)
        }
    }

    var border: Color {
        switch self {
        case .primary: Color.ds.interactionPrimary.opacity(0.2)
        case .secondary: Color.ds.interactionPrimary.opacity(0.18)
        case .subtle: Color.ds.borderSubtle.opacity(0.72)
        case .destructive: Color.ds.critical.opacity(0.2)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, AppSpacing.sm)
            }
            .foregroundStyle(isEnabled ? variant.foreground : Color.ds.textSecondary)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .frame(minHeight: 50)
            .padding(.horizontal, AppSpacing.lg)
            .background(isEnabled ? variant.background : Color.ds.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                    .stroke(isEnabled ? variant.border : Color.ds.borderSubtle, lineWidth: 1)
            }

        }
        .disabled(isLoading)
        .buttonStyle(DSPressButtonStyle())
        .animation(reduceMotion ? nil : AppMotion.quick, value: isLoading)
    }
}

struct DSPressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(reduceMotion ? nil : AppMotion.quick, value: configuration.isPressed)
    }
}
