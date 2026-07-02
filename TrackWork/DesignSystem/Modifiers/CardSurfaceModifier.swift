import SwiftUI

struct CardSurfaceModifier: ViewModifier {
    var includesShadow: Bool = true

    func body(content: Content) -> some View {
        content
            .background(Color.ds.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .stroke(Color.ds.borderSubtle, lineWidth: 1)
            }
            .shadow(
                color: Color.ds.shadowTint.opacity(includesShadow ? AppShadow.cardOpacity : 0),
                radius: AppShadow.cardRadius,
                x: 0,
                y: AppShadow.cardY
            )
    }
}

extension View {
    func cardSurface(includesShadow: Bool = true) -> some View {
        modifier(CardSurfaceModifier(includesShadow: includesShadow))
    }
}
