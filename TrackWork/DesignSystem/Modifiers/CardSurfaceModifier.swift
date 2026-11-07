import SwiftUI

struct CardSurfaceModifier: ViewModifier {
    var includesShadow = false

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
        content
            .background(Color.ds.surfacePrimary, in: shape)
            .overlay(shape.strokeBorder(Color.ds.separator.opacity(0.4), lineWidth: 0.5))
            .shadow(color: Color.ds.shadowTint.opacity(includesShadow ? AppShadow.cardOpacity : 0),
                    radius: AppShadow.cardRadius, y: AppShadow.cardY)
    }
}

struct HeroCardSurfaceModifier: ViewModifier {
    var tint: Color = Color.ds.surfaceBlueTint
    var tintOpacity = 0.58

    func body(content: Content) -> some View {
        content
            .background(Color.ds.surfacePrimary, in: RoundedRectangle(cornerRadius: AppRadius.heroCard))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.heroCard)
                    .strokeBorder(Color.ds.separator.opacity(0.4), lineWidth: 0.5)
            }
    }
}

extension View {
    /// The restrained summary surface used by the approved Home, Calendar and Insights direction.
    func summaryCardSurface() -> some View {
        let shape = RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
        return background(
            LinearGradient(
                colors: [Color.ds.surfaceElevated, Color.ds.surfacePrimary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: shape
        )
        .overlay(shape.strokeBorder(Color.ds.borderSubtle.opacity(0.35), lineWidth: 0.5))
    }

    func cardSurface(includesShadow: Bool = false) -> some View {
        modifier(CardSurfaceModifier(includesShadow: includesShadow))
    }

    func heroCardSurface(tint: Color = Color.ds.surfaceBlueTint, tintOpacity: Double = 0.58) -> some View {
        modifier(HeroCardSurfaceModifier(tint: tint, tintOpacity: tintOpacity))
    }
}
