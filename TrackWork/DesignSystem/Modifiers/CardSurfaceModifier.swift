import SwiftUI

struct CardSurfaceModifier: ViewModifier {
    var includesShadow: Bool = true

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)

        content
            .background(.thinMaterial, in: shape)
            .background(Color.ds.surfacePrimary.opacity(0.42), in: shape)
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.68),
                            Color.ds.borderSubtle.opacity(0.44)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.75
                )
            }
            .shadow(
                color: Color.ds.shadowTint.opacity(includesShadow ? AppShadow.cardOpacity * 0.42 : 0),
                radius: AppShadow.cardRadius * 0.66,
                x: 0,
                y: AppShadow.cardY * 0.58
            )
    }
}

extension View {
    func cardSurface(includesShadow: Bool = true) -> some View {
        modifier(CardSurfaceModifier(includesShadow: includesShadow))
    }
}
