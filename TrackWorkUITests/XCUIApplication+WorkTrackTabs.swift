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

    func openRecords() {
        workTrackTab(named: "Calendar").tap()
        let records = descendants(matching: .any).matching(identifier: "calendar.records").firstMatch
        XCTAssertTrue(records.waitForExistence(timeout: 5))
        records.tap()
    }

    @discardableResult
    func revealElement(_ identifier: String) -> XCUIElement {
        let target = descendants(matching: .any).matching(identifier: identifier).firstMatch
        for _ in 0..<12 {
            if target.exists && target.isHittable { return target }
            swipeUp()
        }
        for _ in 0..<12 {
            if target.exists && target.isHittable { return target }
            swipeDown()
        }
        XCTFail("Unable to reveal \(identifier)")
        return target
    }
}
