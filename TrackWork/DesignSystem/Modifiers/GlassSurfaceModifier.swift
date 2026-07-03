import SwiftUI

struct GlassSurfaceModifier: ViewModifier {
    var cornerRadius: CGFloat = AppRadius.card
    var tint: Color = Color.ds.surfaceGlass
    var isInteractive: Bool = false

    func body(content: Content) -> some View {
        content
            .modifier(
                LiquidGlassSurfaceModifier(
                    cornerRadius: cornerRadius,
                    tint: tint,
                    isInteractive: isInteractive
                )
            )
    }
}

private struct LiquidGlassSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color
    let isInteractive: Bool

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.ds.borderSubtle.opacity(0.7), lineWidth: 1)
            }
            .glassEffect(
                isInteractive ? .regular.tint(tint.opacity(0.22)).interactive() : .regular.tint(tint.opacity(0.16)),
                in: .rect(cornerRadius: cornerRadius)
            )
    }
}

extension View {
    func glassSurface(
        cornerRadius: CGFloat = AppRadius.card,
        tint: Color = Color.ds.surfaceGlass,
        isInteractive: Bool = false
    ) -> some View {
        modifier(
            GlassSurfaceModifier(
                cornerRadius: cornerRadius,
                tint: tint,
                isInteractive: isInteractive
            )
        )
    }
}
