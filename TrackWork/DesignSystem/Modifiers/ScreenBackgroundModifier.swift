import SwiftUI

struct ScreenBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    Color.ds.backgroundPrimary

                    LinearGradient(
                        colors: [
                            Color.ds.backgroundSoftBlue.opacity(0.38),
                            Color.ds.backgroundSecondary.opacity(0.18),
                            Color.ds.backgroundPrimary.opacity(0.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: UnitPoint(x: 0.68, y: 0.58)
                    )

                    RadialGradient(
                        colors: [
                            Color.ds.accentSoft.opacity(0.14),
                            Color.ds.backgroundPrimary.opacity(0.0)
                        ],
                        center: .bottomTrailing,
                        startRadius: 40,
                        endRadius: 520
                    )
                }
                .ignoresSafeArea()
            }
    }
}

extension View {
    func appScreenBackground() -> some View {
        modifier(ScreenBackgroundModifier())
    }
}
