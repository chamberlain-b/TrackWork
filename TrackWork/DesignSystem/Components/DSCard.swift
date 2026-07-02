import SwiftUI

struct DSCard<Content: View>: View {
    private let includesShadow: Bool
    private let content: Content

    init(includesShadow: Bool = true, @ViewBuilder content: () -> Content) {
        self.includesShadow = includesShadow
        self.content = content()
    }

    var body: some View {
        content
            .padding(AppSpacing.md)
            .cardSurface(includesShadow: includesShadow)
    }
}

#Preview {
    DSCard {
        Text("Card surface")
            .font(AppTypography.cardTitle)
            .foregroundStyle(Color.ds.textPrimary)
    }
    .padding()
    .appScreenBackground()
}
