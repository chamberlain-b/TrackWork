import CoreLocation
import XCTest
@testable import TrackWork

final class OneShotCheckInServiceTests: XCTestCase {
    private let service = OneShotCheckInService()

    func testClassifiesLocationInsideActiveOfficeRadius() {
        let office = Place(
            name: "Melbourne Office",
            type: .office,
            latitude: -37.8136,
            longitude: 144.9631,
            radiusMeters: 150
        )
        let inactiveHome = Place(
            name: "Inactive Home",
            type: .home,
            latitude: -37.8136,
            longitude: 144.9631,
            radiusMeters: 150,
            isActive: false
        )

        let result = service.classify(
            CLLocation(latitude: -37.8136, longitude: 144.9631),
            against: [inactiveHome, office]
        )

        XCTAssertEqual(result.outcome, .matched)
        XCTAssertEqual(result.classification, .office)
        XCTAssertEqual(result.matchedPlaceID, office.id)
        XCTAssertEqual(result.matchedPlaceName, "Melbourne Office")
        XCTAssertTrue(result.canApplyToAttendance)
    }

    func testLocationOutsideSavedRadiiRemainsUnknown() {
        let office = Place(
            name: "Melbourne Office",
            type: .office,
            latitude: -37.8136,
            longitude: 144.9631,
            radiusMeters: 100
        )

        let result = service.classify(
            CLLocation(latitude: -33.8688, longitude: 151.2093),
            against: [office]
        )

        XCTAssertEqual(result.outcome, .outsideSavedPlaces)
        XCTAssertEqual(result.classification, .unknown)
        XCTAssertNil(result.matchedPlaceID)
        XCTAssertNil(result.matchedPlaceName)
        XCTAssertFalse(result.canApplyToAttendance)
    }

    func testOverlappingHomeAndOfficeRadiiRequireReview() {
        let home = Place(
            name: "Home",
            type: .home,
            latitude: -37.8136,
            longitude: 144.9631,
            radiusMeters: 150
        )
        let office = Place(
            name: "Office",
            type: .office,
            latitude: -37.8136,
            longitude: 144.9631,
            radiusMeters: 150
        )

        let result = service.classify(
            CLLocation(latitude: -37.8136, longitude: 144.9631),
            against: [home, office]
        )

        XCTAssertEqual(result.outcome, .ambiguousMatches)
        XCTAssertEqual(result.classification, .unknown)
        XCTAssertFalse(result.canApplyToAttendance)
    }

    func testApplyingMatchUpdatesDetectedAndFinalClassification() {
        let office = Place(
            name: "Office",
            type: .office,
            latitude: -37.8136,
            longitude: 144.9631
        )
        let result = service.classify(
            CLLocation(latitude: -37.8136, longitude: 144.9631),
            against: [office]
        )
        let updatedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let attendanceDay = AttendanceDay(date: updatedAt)

        let applicationResult = service.apply(result, to: attendanceDay, updatedAt: updatedAt)

        XCTAssertEqual(applicationResult, .appliedDetectedAndFinal)
        XCTAssertEqual(attendanceDay.detectedClassification, .office)
        XCTAssertEqual(attendanceDay.finalClassification, .office)
        XCTAssertEqual(attendanceDay.complianceTreatment, .countsAsOffice)
        XCTAssertEqual(attendanceDay.updatedAt, updatedAt)
    }

    func testApplyingMatchDoesNotOverrideManualClassification() {
        let office = Place(
            name: "Office",
            type: .office,
            latitude: -37.8136,
            longitude: 144.9631
        )
        let result = service.classify(
            CLLocation(latitude: -37.8136, longitude: 144.9631),
            against: [office]
        )
        let attendanceDay = AttendanceDay(
            date: .now,
            detectedClassification: .unknown,
            finalClassification: .home,
            manualClassification: .home,
            complianceTreatment: .countsAsHome
        )

        let applicationResult = service.apply(result, to: attendanceDay)

        XCTAssertEqual(applicationResult, .appliedDetectedPreservingManualFinal)
        XCTAssertEqual(attendanceDay.detectedClassification, .office)
        XCTAssertEqual(attendanceDay.finalClassification, .home)
        XCTAssertEqual(attendanceDay.manualClassification, .home)
        XCTAssertEqual(attendanceDay.complianceTreatment, .countsAsHome)
    }

    func testApplyingMatchPreservesLeaveAndHolidayFinalStatuses() {
        let home = Place(
            name: "Home",
            type: .home,
            latitude: -37.8136,
            longitude: 144.9631
        )
        let result = service.classify(
            CLLocation(latitude: -37.8136, longitude: 144.9631),
            against: [home]
        )
        let attendanceDay = AttendanceDay(
            date: .now,
            detectedClassification: .unknown,
            finalClassification: .annualLeave,
            complianceTreatment: .excludedFromRequirement
        )

        let applicationResult = service.apply(result, to: attendanceDay)

        XCTAssertEqual(applicationResult, .appliedDetectedPreservingExcludedFinal)
        XCTAssertEqual(attendanceDay.detectedClassification, .home)
        XCTAssertEqual(attendanceDay.finalClassification, .annualLeave)
        XCTAssertEqual(attendanceDay.complianceTreatment, .excludedFromRequirement)
    }

    func testUnmatchedResultDoesNotMutateAttendance() {
        let result = service.classify(CLLocation(latitude: 0, longitude: 0), against: [])
        let originalUpdatedAt = Date(timeIntervalSince1970: 1_600_000_000)
        let attendanceDay = AttendanceDay(
            date: originalUpdatedAt,
            detectedClassification: .home,
            finalClassification: .home,
            complianceTreatment: .countsAsHome,
            updatedAt: originalUpdatedAt
        )

        XCTAssertEqual(service.apply(result, to: attendanceDay), .notApplied)
        XCTAssertEqual(attendanceDay.detectedClassification, .home)
        XCTAssertEqual(attendanceDay.finalClassification, .home)
        XCTAssertEqual(attendanceDay.updatedAt, originalUpdatedAt)
    }
}
