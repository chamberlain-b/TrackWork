import SwiftUI

enum AppTypography {
    static let screenTitle = Font.largeTitle.weight(.bold)
    static let title = Font.title2.weight(.semibold)
    static let sectionTitle = Font.headline.weight(.semibold)
    static let cardTitle = Font.headline.weight(.semibold)
    static let headline = Font.headline.weight(.semibold)
    static let body = Font.body
    static let callout = Font.subheadline
    static let caption = Font.caption
    static let captionStrong = Font.caption.weight(.semibold)
    static let heroMetric = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let metric = Font.system(.title, design: .rounded, weight: .bold)
    static let smallMetric = Font.system(.title3, design: .rounded, weight: .semibold)
}
