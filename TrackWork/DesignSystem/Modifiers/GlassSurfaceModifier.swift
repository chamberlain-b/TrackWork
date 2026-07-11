import SwiftUI

struct GlassSurfaceModifier: ViewModifier {
    var cornerRadius: CGFloat = AppRadius.card
    var tint: Color = Color.ds.surfaceGlass
    var isInteractive: Bool = false

    func body(content: Content) -> some View {
        if isInteractive {
            content
                .glassEffect(
                    .regular.tint(tint.opacity(0.22)).interactive(),
                    in: .rect(cornerRadius: cornerRadius)
                )
        } else {
            content
                .background(
                    .regularMaterial,
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.ds.borderSubtle.opacity(0.7), lineWidth: 1)
                }
        }
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
