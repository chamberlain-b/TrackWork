import SwiftUI

struct ScreenBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    Color.ds.backgroundPrimary

                    LinearGradient(
                        colors: [
                            Color.ds.backgroundSoftBlue.opacity(0.5),
                            Color.ds.backgroundSecondary.opacity(0.28),
                            Color.ds.backgroundPrimary.opacity(0.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .center
                    )

                    LinearGradient(
                        colors: [
                            Color.ds.accentSoft.opacity(0.2),
                            Color.ds.backgroundPrimary.opacity(0.0)
                        ],
                        startPoint: .bottomTrailing,
                        endPoint: .center
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
