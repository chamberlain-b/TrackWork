import SwiftUI

struct ScreenBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(Color.ds.backgroundPrimary.ignoresSafeArea())
    }
}

extension View {
    func appScreenBackground() -> some View {
        modifier(ScreenBackgroundModifier())
    }
}
