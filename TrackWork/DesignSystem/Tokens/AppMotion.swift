import SwiftUI

enum AppMotion {
    static let quick = Animation.easeOut(duration: 0.18)
    static let standard = Animation.easeInOut(duration: 0.25)
    static let smooth = Animation.spring(response: 0.35, dampingFraction: 0.85)
}
