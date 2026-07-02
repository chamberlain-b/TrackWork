import XCTest
@testable import TrackWork

final class AttendanceEnumTests: XCTestCase {
    func testDisplayNamesAreNonEmpty() {
        let displayNames = [
            AttendanceClassification.allCases.map(\.displayName),
            ComplianceTreatment.allCases.map(\.displayName),
            LeaveType.allCases.map(\.displayName),
            LeaveDuration.allCases.map(\.displayName),
            RequirementType.allCases.map(\.displayName),
            ComplianceStatus.allCases.map(\.displayName),
            OverrideReason.allCases.map(\.displayName)
        ].flatMap { $0 }

        XCTAssertFalse(displayNames.isEmpty)
        XCTAssertTrue(displayNames.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
    }

    func testAttendanceClassificationRawValuesAreStable() {
        XCTAssertEqual(AttendanceClassification.office.rawValue, "office")
        XCTAssertEqual(AttendanceClassification.home.rawValue, "home")
        XCTAssertEqual(AttendanceClassification.mixed.rawValue, "mixed")
        XCTAssertEqual(AttendanceClassification.annualLeave.rawValue, "annualLeave")
        XCTAssertEqual(AttendanceClassification.sickLeave.rawValue, "sickLeave")
        XCTAssertEqual(AttendanceClassification.publicHoliday.rawValue, "publicHoliday")
        XCTAssertEqual(AttendanceClassification.weekend.rawValue, "weekend")
        XCTAssertEqual(AttendanceClassification.nonWorkingDay.rawValue, "nonWorkingDay")
        XCTAssertEqual(AttendanceClassification.unknown.rawValue, "unknown")
    }

    func testComplianceTreatmentRawValuesAreStable() {
        XCTAssertEqual(ComplianceTreatment.countsAsOffice.rawValue, "countsAsOffice")
        XCTAssertEqual(ComplianceTreatment.countsAsHome.rawValue, "countsAsHome")
        XCTAssertEqual(ComplianceTreatment.excludedFromRequirement.rawValue, "excludedFromRequirement")
        XCTAssertEqual(ComplianceTreatment.requiresReview.rawValue, "requiresReview")
    }

    func testLeaveTypeRawValuesAreStable() {
        XCTAssertEqual(LeaveType.annualLeave.rawValue, "annualLeave")
        XCTAssertEqual(LeaveType.sickLeave.rawValue, "sickLeave")
    }

    func testLeaveDurationRawValuesAreStable() {
        XCTAssertEqual(LeaveDuration.fullDay.rawValue, "fullDay")
        XCTAssertEqual(LeaveDuration.halfDayAM.rawValue, "halfDayAM")
        XCTAssertEqual(LeaveDuration.halfDayPM.rawValue, "halfDayPM")
    }

    func testRequirementTypeRawValuesAreStable() {
        XCTAssertEqual(RequirementType.fixedMonthlyDays.rawValue, "fixedMonthlyDays")
        XCTAssertEqual(RequirementType.percentageOfEligibleDays.rawValue, "percentageOfEligibleDays")
    }

    func testComplianceStatusRawValuesAreStable() {
        XCTAssertEqual(ComplianceStatus.complete.rawValue, "complete")
        XCTAssertEqual(ComplianceStatus.onTrack.rawValue, "onTrack")
        XCTAssertEqual(ComplianceStatus.atRisk.rawValue, "atRisk")
        XCTAssertEqual(ComplianceStatus.impossible.rawValue, "impossible")
    }

    func testOverrideReasonRawValuesAreStable() {
        XCTAssertEqual(OverrideReason.forgotWorkPass.rawValue, "forgotWorkPass")
        XCTAssertEqual(OverrideReason.phoneLocationIncorrect.rawValue, "phoneLocationIncorrect")
        XCTAssertEqual(OverrideReason.phoneBatteryFlat.rawValue, "phoneBatteryFlat")
        XCTAssertEqual(OverrideReason.manualCorrection.rawValue, "manualCorrection")
        XCTAssertEqual(OverrideReason.other.rawValue, "other")
    }

    func testLeaveDurationIncludesFullDayAndFutureHalfDayCases() {
        XCTAssertTrue(LeaveDuration.allCases.contains(.fullDay))
        XCTAssertTrue(LeaveDuration.allCases.contains(.halfDayAM))
        XCTAssertTrue(LeaveDuration.allCases.contains(.halfDayPM))
    }
}
