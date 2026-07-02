import XCTest
@testable import TrackWork

final class JurisdictionCatalogTests: XCTestCase {
    func testCountryDisplayNames() {
        XCTAssertEqual(Country.australia.displayName, "Australia")
        XCTAssertEqual(Country.newZealand.displayName, "New Zealand")
    }

    func testAustralianJurisdictionCountIsEight() {
        XCTAssertEqual(JurisdictionCatalog.jurisdictions(for: .australia).count, 8)
    }

    func testNewZealandJurisdictionsIncludeNationalAndAuckland() {
        let ids = Set(JurisdictionCatalog.jurisdictions(for: .newZealand).map(\.id))

        XCTAssertTrue(ids.contains("NZ-NATIONAL"))
        XCTAssertTrue(ids.contains("NZ-AUCKLAND"))
    }

    func testJurisdictionIDsAreUnique() {
        let ids = JurisdictionCatalog.all.map(\.id)

        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testFilteringByCountryReturnsOnlyExpectedCountry() {
        for country in Country.allCases {
            let jurisdictions = JurisdictionCatalog.jurisdictions(for: country)

            XCTAssertFalse(jurisdictions.isEmpty)
            XCTAssertTrue(jurisdictions.allSatisfy { $0.country == country })
        }
    }
}
