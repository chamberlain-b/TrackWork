import XCTest

extension XCUIApplication {
    func workTrackTab(named label: String) -> XCUIElement {
        let candidates = descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", label)
        )

        for index in 0..<candidates.count {
            let candidate = candidates.element(boundBy: index)
            if candidate.isHittable {
                return candidate
            }
        }

        return candidates.firstMatch
    }
}
