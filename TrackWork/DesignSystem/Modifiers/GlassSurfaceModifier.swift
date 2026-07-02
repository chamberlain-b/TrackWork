import SwiftUI

struct GlassSurfaceModifier: ViewModifier {
    var cornerRadius: CGFloat = AppRadius.card

    func body(content: Content) -> some View {
        content
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.ds.borderSubtle.opacity(0.85), lineWidth: 1)
            }
    }
}

extension View {
    func glassSurface(cornerRadius: CGFloat = AppRadius.card) -> some View {
        modifier(GlassSurfaceModifier(cornerRadius: cornerRadius))
    }
}
