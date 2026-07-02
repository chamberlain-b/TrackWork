import SwiftUI

struct ScreenBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    Color.ds.backgroundPrimary
                    LinearGradient(
                        colors: [
                            Color.ds.backgroundSoftBlue.opacity(0.65),
                            Color.ds.backgroundPrimary.opacity(0.0)
                        ],
                        startPoint: .top,
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
