import SwiftUI

enum DSIconBadgeStyle: CaseIterable {
    case accent
    case success
    case warning
    case critical
    case office
    case home
    case leave

    var foreground: Color {
        switch self {
        case .accent: Color.ds.accentPrimary
        case .success: Color.ds.success
        case .warning: Color.ds.warning
        case .critical: Color.ds.critical
        case .office: Color.ds.officeDay
        case .home: Color.ds.homeDay
        case .leave: Color.ds.leaveDay
        }
    }

    var background: Color {
        foreground.opacity(0.12)
    }
}

struct DSIconBadge: View {
    let systemImage: String
    var style: DSIconBadgeStyle = .accent
    var size: CGFloat = 32

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: max(size * 0.42, 14), weight: .semibold))
            .foregroundStyle(style.foreground)
            .frame(width: size, height: size)
            .background(style.background)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(Color.ds.borderSubtle, lineWidth: 1)
            }
            .accessibilityHidden(true)
    }
}
