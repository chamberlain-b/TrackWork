import XCTest
@testable import TrackWork

final class AttendanceInferenceServiceTests: XCTestCase {
    private var calendar: Calendar!
    private var service: AttendanceInferenceService!

    override func setUp() {
        super.setUp()

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
        service = AttendanceInferenceService(calendar: calendar, minimumOfficeMinutes: 180)
    }

    override func tearDown() {
        calendar = nil
        service = nil

        super.tearDown()
    }

    func testOfficeVisitAboveThresholdCountsAsDetectedOffice() throws {
        let inferences = service.inferDailyAttendance(
            from: [
                event(.office, .entered, "2026-07-06 09:00"),
                event(.office, .exited, "2026-07-06 12:30")
            ],
            periodStart: day("2026-07-06"),
            periodEnd: day("2026-07-06")
        )

        let inference = try XCTUnwrap(inferences.first)
        XCTAssertEqual(inference.officeMinutes, 210)
        XCTAssertEqual(inference.homeMinutes, 0)
        XCTAssertEqual(inference.detectedClassification, .office)
        XCTAssertEqual(inference.finalClassification, .office)
        XCTAssertEqual(inference.complianceTreatment, .countsAsOffice)
    }

    func testOfficeVisitBelowThresholdDoesNotCountAsOfficeWithoutManualOverride() throws {
        let inferences = service.inferDailyAttendance(
            from: [
                event(.office, .entered, "2026-07-06 09:00"),
                event(.office, .exited, "2026-07-06 11:59")
            ],
            periodStart: day("2026-07-06"),
            periodEnd: day("2026-07-06")
        )

        let inference = try XCTUnwrap(inferences.first)
        XCTAssertEqual(inference.officeMinutes, 179)
        XCTAssertEqual(inference.detectedClassification, .unknown)
        XCTAssertEqual(inference.finalClassification, .unknown)
        XCTAssertEqual(inference.complianceTreatment, .requiresReview)
    }

    func testHomeAndOfficeEvidenceBelowThresholdRecordsMixedDay() throws {
        let inferences = service.inferDailyAttendance(
            from: [
                event(.home, .entered, "2026-07-06 08:00"),
                event(.home, .exited, "2026-07-06 09:00"),
                event(.office, .entered, "2026-07-06 10:00"),
                event(.office, .exited, "2026-07-06 12:59")
            ],
            periodStart: day("2026-07-06"),
            periodEnd: day("2026-07-06")
        )

        let inference = try XCTUnwrap(inferences.first)
        XCTAssertEqual(inference.officeMinutes, 179)
        XCTAssertEqual(inference.homeMinutes, 60)
        XCTAssertEqual(inference.detectedClassification, .mixed)
        XCTAssertEqual(inference.finalClassification, .mixed)
        XCTAssertEqual(inference.complianceTreatment, .countsAsHome)
    }

    func testOfficeThresholdWithHomeEvidenceRecordsOfficeDay() throws {
        let inferences = service.inferDailyAttendance(
            from: [
                event(.home, .entered, "2026-07-06 07:30"),
                event(.home, .exited, "2026-07-06 08:00"),
                event(.office, .entered, "2026-07-06 09:00"),
                event(.office, .exited, "2026-07-06 12:00")
            ],
            periodStart: day("2026-07-06"),
            periodEnd: day("2026-07-06")
        )

        let inference = try XCTUnwrap(inferences.first)
        XCTAssertEqual(inference.officeMinutes, 180)
        XCTAssertEqual(inference.homeMinutes, 30)
        XCTAssertEqual(inference.detectedClassification, .office)
        XCTAssertEqual(inference.finalClassification, .office)
        XCTAssertEqual(inference.complianceTreatment, .countsAsOffice)
    }

    func testManualOverrideIsNotOverwrittenDuringRecalculation() {
        let attendanceDay = AttendanceDay(
            date: day("2026-07-06"),
            detectedClassification: .unknown,
            finalClassification: .office,
            manualClassification: .office,
            complianceTreatment: .countsAsOffice
        )

        let affectedDates = service.recalculateAttendanceDays(
            [attendanceDay],
            events: [
                event(.office, .entered, "2026-07-06 09:00"),
                event(.office, .exited, "2026-07-06 09:30")
            ],
            updatedAt: dateTime("2026-07-06 13:00")
        )

        XCTAssertEqual(affectedDates, [day("2026-07-06")])
        XCTAssertEqual(attendanceDay.officeMinutes, 30)
        XCTAssertEqual(attendanceDay.detectedClassification, .unknown)
        XCTAssertEqual(attendanceDay.finalClassification, .office)
        XCTAssertEqual(attendanceDay.manualClassification, .office)
        XCTAssertEqual(attendanceDay.complianceTreatment, .countsAsOffice)
    }

    func testLeaveDayRemainsExcludedEvenWhenLocationEventsExist() throws {
        let leaveRecord = LeaveRecord(date: day("2026-07-06"), leaveType: .annualLeave)
        let inferences = service.inferDailyAttendance(
            from: [
                event(.office, .entered, "2026-07-06 09:00"),
                event(.office, .exited, "2026-07-06 13:00")
            ],
            periodStart: day("2026-07-06"),
            periodEnd: day("2026-07-06"),
            leaveRecords: [leaveRecord]
        )

        let inference = try XCTUnwrap(inferences.first)
        XCTAssertEqual(inference.officeMinutes, 240)
        XCTAssertEqual(inference.detectedClassification, .office)
        XCTAssertEqual(inference.finalClassification, .annualLeave)
        XCTAssertEqual(inference.complianceTreatment, .excludedFromRequirement)
    }

    func testPublicHolidayRemainsExcludedEvenWhenLocationEventsExist() throws {
        let holiday = PublicHoliday(
            date: day("2026-07-06"),
            name: "Test Holiday",
            country: .australia,
            jurisdictionId: "AU-VIC",
            isRegional: false,
            sourceName: "Test"
        )
        let inferences = service.inferDailyAttendance(
            from: [
                event(.office, .entered, "2026-07-06 09:00"),
                event(.office, .exited, "2026-07-06 13:00")
            ],
            periodStart: day("2026-07-06"),
            periodEnd: day("2026-07-06"),
            publicHolidays: [holiday]
        )

        let inference = try XCTUnwrap(inferences.first)
        XCTAssertEqual(inference.detectedClassification, .office)
        XCTAssertEqual(inference.finalClassification, .publicHoliday)
        XCTAssertEqual(inference.complianceTreatment, .excludedFromRequirement)
    }

    func testPublicHolidayTakesPrecedenceOverLeaveAndCustomExclusion() throws {
        let subjectDate = day("2026-07-06")
        let holiday = PublicHoliday(
            date: subjectDate,
            name: "Test Holiday",
            country: .australia,
            jurisdictionId: "AU-VIC",
            isRegional: false,
            sourceName: "Test"
        )

        let inference = try XCTUnwrap(
            service.inferDailyAttendance(
                from: [],
                periodStart: subjectDate,
                periodEnd: subjectDate,
                leaveRecords: [LeaveRecord(date: subjectDate, leaveType: .annualLeave)],
                publicHolidays: [holiday],
                customExcludedDays: [CustomExcludedDay(date: subjectDate)]
            ).first
        )

        XCTAssertEqual(inference.finalClassification, .publicHoliday)
        XCTAssertEqual(inference.complianceTreatment, .excludedFromRequirement)
    }

    func testLeaveTakesPrecedenceOverCustomExclusionAndManualStatus() {
        let subjectDate = day("2026-07-06")
        let attendanceDay = AttendanceDay(
            date: subjectDate,
            detectedClassification: .unknown,
            finalClassification: .office,
            manualClassification: .office,
            complianceTreatment: .countsAsOffice
        )

        service.recalculateAttendanceDays(
            [attendanceDay],
            affectedDates: [subjectDate],
            events: [],
            leaveRecords: [LeaveRecord(date: subjectDate, leaveType: .sickLeave)],
            customExcludedDays: [CustomExcludedDay(date: subjectDate)]
        )

        XCTAssertEqual(attendanceDay.finalClassification, .sickLeave)
        XCTAssertEqual(attendanceDay.manualClassification, .office)
        XCTAssertEqual(attendanceDay.complianceTreatment, .excludedFromRequirement)
    }

    func testCustomExclusionKeepsDetectedStatusAndForcesNonWorkingTreatment() throws {
        let excludedDay = CustomExcludedDay(
            date: day("2026-07-06"),
            reason: "Company closure"
        )
        let inferences = service.inferDailyAttendance(
            from: [
                event(.office, .entered, "2026-07-06 09:00"),
                event(.office, .exited, "2026-07-06 13:00")
            ],
            periodStart: day("2026-07-06"),
            periodEnd: day("2026-07-06"),
            customExcludedDays: [excludedDay]
        )

        let inference = try XCTUnwrap(inferences.first)
        XCTAssertEqual(inference.officeMinutes, 240)
        XCTAssertEqual(inference.detectedClassification, .office)
        XCTAssertEqual(inference.finalClassification, .nonWorkingDay)
        XCTAssertEqual(inference.complianceTreatment, .excludedFromRequirement)
    }

    func testRecalculationHonorsCustomExclusionWithManualStatusAndRestoresItAfterRemoval() {
        let attendanceDay = AttendanceDay(
            date: day("2026-07-06"),
            detectedClassification: .unknown,
            finalClassification: .home,
            manualClassification: .home,
            complianceTreatment: .countsAsHome
        )
        let events = [
            event(.office, .entered, "2026-07-06 09:00"),
            event(.office, .exited, "2026-07-06 13:00")
        ]
        let excludedDay = CustomExcludedDay(date: day("2026-07-06"))

        service.recalculateAttendanceDays(
            [attendanceDay],
            events: events,
            customExcludedDays: [excludedDay],
            updatedAt: dateTime("2026-07-06 13:00")
        )

        XCTAssertEqual(attendanceDay.detectedClassification, .office)
        XCTAssertEqual(attendanceDay.finalClassification, .nonWorkingDay)
        XCTAssertEqual(attendanceDay.manualClassification, .home)
        XCTAssertEqual(attendanceDay.complianceTreatment, .excludedFromRequirement)

        service.recalculateAttendanceDays(
            [attendanceDay],
            events: events,
            updatedAt: dateTime("2026-07-06 14:00")
        )

        XCTAssertEqual(attendanceDay.detectedClassification, .office)
        XCTAssertEqual(attendanceDay.finalClassification, .home)
        XCTAssertEqual(attendanceDay.manualClassification, .home)
        XCTAssertEqual(attendanceDay.complianceTreatment, .countsAsHome)
    }

    func testRecalculateAffectedAttendanceDayRecordsWhenEventsChange() {
        let affectedDay = AttendanceDay(
            date: day("2026-07-06"),
            detectedClassification: .unknown,
            finalClassification: .unknown
        )
        let unaffectedDay = AttendanceDay(
            date: day("2026-07-07"),
            detectedClassification: .home,
            finalClassification: .home,
            homeMinutes: 60
        )

        let affectedDates = service.recalculateAttendanceDays(
            [affectedDay, unaffectedDay],
            events: [
                event(.office, .entered, "2026-07-06 09:00"),
                event(.office, .exited, "2026-07-06 12:00")
            ],
            updatedAt: dateTime("2026-07-06 13:00")
        )

        XCTAssertEqual(affectedDates, [day("2026-07-06")])
        XCTAssertEqual(affectedDay.officeMinutes, 180)
        XCTAssertEqual(affectedDay.detectedClassification, .office)
        XCTAssertEqual(affectedDay.finalClassification, .office)
        XCTAssertEqual(affectedDay.complianceTreatment, .countsAsOffice)
        XCTAssertEqual(unaffectedDay.detectedClassification, .home)
        XCTAssertEqual(unaffectedDay.finalClassification, .home)
        XCTAssertEqual(unaffectedDay.homeMinutes, 60)
    }

    func testCrossMidnightVisitMarksAndAllocatesBothDates() throws {
        let events = [
            event(.office, .entered, "2026-07-06 22:00"),
            event(.office, .exited, "2026-07-07 02:00")
        ]

        XCTAssertEqual(
            LocationEventDateResolver(calendar: calendar).affectedDates(from: events),
            [day("2026-07-06"), day("2026-07-07")]
        )

        let inferences = service.inferDailyAttendance(
            from: events,
            periodStart: day("2026-07-06"),
            periodEnd: day("2026-07-07")
        )

        XCTAssertEqual(inferences.count, 2)
        XCTAssertEqual(inferences[0].officeMinutes, 120)
        XCTAssertEqual(inferences[1].officeMinutes, 120)
    }

    func testUnclosedEntryStillMarksItsDateForReview() {
        let events = [event(.office, .entered, "2026-07-06 09:00")]

        XCTAssertEqual(
            LocationEventDateResolver(calendar: calendar).affectedDates(from: events),
            [day("2026-07-06")]
        )
    }

    private func event(_ placeType: PlaceType, _ eventKind: LocationEventKind, _ timestamp: String) -> LocationEvent {
        let placeId = switch placeType {
        case .office:
            UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        case .home:
            UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        }
        return LocationEvent(
            placeId: placeId,
            placeName: placeType.displayName,
            placeType: placeType,
            eventKind: eventKind,
            regionIdentifier: "worktrack.place.\(placeType.rawValue).\(placeId.uuidString)",
            occurredAt: dateTime(timestamp),
            createdAt: dateTime(timestamp)
        )
    }

    private func day(_ isoDate: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        guard let date = formatter.date(from: isoDate) else {
            XCTFail("Invalid test fixture date: \(isoDate)")
            return Date(timeIntervalSince1970: 0)
        }

        return date
    }

    private func dateTime(_ timestamp: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"

        guard let date = formatter.date(from: timestamp) else {
            XCTFail("Invalid test fixture timestamp: \(timestamp)")
            return Date(timeIntervalSince1970: 0)
        }

        return date
    }
}
