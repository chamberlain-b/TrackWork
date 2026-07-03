import SwiftUI

enum DSStatusPillStyle: CaseIterable {
    case info
    case success
    case warning
    case critical
    case neutral

    var foreground: Color {
        switch self {
        case .info: Color.ds.info
        case .success: Color.ds.success
        case .warning: Color.ds.warning
        case .critical: Color.ds.critical
        case .neutral: Color.ds.textSecondary
        }
    }

    var background: Color {
        switch self {
        case .info: Color.ds.info.opacity(0.1)
        case .success: Color.ds.success.opacity(0.1)
        case .warning: Color.ds.warning.opacity(0.12)
        case .critical: Color.ds.critical.opacity(0.1)
        case .neutral: Color.ds.surfaceSecondary.opacity(0.82)
        }
    }
}

struct DSStatusPill: View {
    let text: String
    var systemImage: String?
    var style: DSStatusPillStyle = .neutral

    var body: some View {
        Label {
            Text(text)
                .font(AppTypography.captionStrong)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        } icon: {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.semibold))
            }
        }
        .foregroundStyle(style.foreground)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(style.background, in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .stroke(style.foreground.opacity(0.16), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}
