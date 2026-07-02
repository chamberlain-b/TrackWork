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
        case .info: Color.ds.info.opacity(0.12)
        case .success: Color.ds.success.opacity(0.12)
        case .warning: Color.ds.warning.opacity(0.14)
        case .critical: Color.ds.critical.opacity(0.12)
        case .neutral: Color.ds.surfaceSecondary
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
        } icon: {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.semibold))
            }
        }
        .foregroundStyle(style.foreground)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(style.background)
        .clipShape(Capsule(style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
