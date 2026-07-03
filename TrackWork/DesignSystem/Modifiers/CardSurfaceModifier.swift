import SwiftUI

struct CardSurfaceModifier: ViewModifier {
    var includesShadow: Bool = true

    func body(content: Content) -> some View {
        content
            .background(Color.ds.surfacePrimary.opacity(0.94))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .stroke(Color.ds.borderSubtle.opacity(0.72), lineWidth: 1)
            }
            .shadow(
                color: Color.ds.shadowTint.opacity(includesShadow ? AppShadow.cardOpacity * 0.55 : 0),
                radius: AppShadow.cardRadius * 0.72,
                x: 0,
                y: AppShadow.cardY * 0.72
            )
    }
}

extension View {
    func cardSurface(includesShadow: Bool = true) -> some View {
        modifier(CardSurfaceModifier(includesShadow: includesShadow))
    }
}
