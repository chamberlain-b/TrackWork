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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let text: String
    var systemImage: String?
    var style: DSStatusPillStyle = .neutral
    var statusColor: Color? = nil

    var body: some View {
        Label {
            Text(text)
                .font(AppTypography.captionStrong)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(Color.ds.textPrimary)
        } icon: {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(statusColor ?? style.foreground)
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(
            Color.ds.surfaceSecondary,
            in: RoundedRectangle(cornerRadius: pillCornerRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: pillCornerRadius, style: .continuous)
                .stroke((statusColor ?? style.foreground).opacity(0.16), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var pillCornerRadius: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? AppRadius.md : AppRadius.pill
    }
}
