import SwiftData
import XCTest
@testable import TrackWork

@MainActor
final class DataManagementServiceTests: XCTestCase {
    func testResetDeletesUserOwnedRecordsGeneratedExportsAndRestoresDefaultRule() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let attendanceDay = AttendanceDay(
            date: date("2026-07-06"),
            detectedClassification: .home,
            finalClassification: .office,
            manualClassification: .office,
            complianceTreatment: .countsAsOffice,
            note: "Private note"
        )

        context.insert(attendanceDay)
        context.insert(LeaveRecord(date: date("2026-07-07"), leaveType: .sickLeave, note: "Private leave note"))
        context.insert(CustomExcludedDay(date: date("2026-07-08"), reason: "Private exclusion"))
        context.insert(PlannedOfficeDay(date: date("2026-07-09"), note: "Private office plan"))
        context.insert(
            ManualAdjustment(
                attendanceDayId: attendanceDay.id,
                adjustedClassification: .office,
                reason: .manualCorrection,
                note: "Private correction"
            )
        )
        context.insert(
            ComplianceRule(
                name: "Custom rule",
                country: .newZealand,
                jurisdictionId: "NZ-AUCKLAND",
                fixedRequiredDays: 12
            )
        )

        let place = Place(
            name: "Private home",
            type: .home,
            latitude: -37.8136,
            longitude: 144.9631
        )
        context.insert(place)
        context.insert(
            LocationEvent(
                placeId: place.id,
                placeName: place.name,
                placeType: .home,
                eventKind: .entered,
                regionIdentifier: "worktrack.place.home.\(place.id.uuidString)"
            )
        )
        context.insert(
            PublicHoliday(
                date: date("2026-07-10"),
                name: "Bundled holiday",
                country: .australia,
                jurisdictionId: "AU-VIC",
                isRegional: false,
                sourceName: "Bundled fixture"
            )
        )
        context.insert(
            PublicHoliday(
                date: date("2026-07-13"),
                name: "Custom holiday edit",
                country: .australia,
                jurisdictionId: "AU-VIC",
                isRegional: true,
                sourceName: "User",
                isUserEdited: true
            )
        )
        try context.save()

        let exportDirectory = temporaryExportDirectory()
        let exportStore = GeneratedExportStore(directoryURL: exportDirectory)
        let generatedReportURL = try exportStore.fileURL(named: "private-report.csv")
        try Data("private report".utf8).write(to: generatedReportURL)

        try DataManagementService(generatedExportStore: exportStore).resetUserData(in: context)

        XCTAssertTrue(try fetch(AttendanceDay.self, from: context).isEmpty)
        XCTAssertTrue(try fetch(LeaveRecord.self, from: context).isEmpty)
        XCTAssertTrue(try fetch(CustomExcludedDay.self, from: context).isEmpty)
        XCTAssertTrue(try fetch(PlannedOfficeDay.self, from: context).isEmpty)
        XCTAssertTrue(try fetch(ManualAdjustment.self, from: context).isEmpty)
        XCTAssertTrue(try fetch(Place.self, from: context).isEmpty)
        XCTAssertTrue(try fetch(LocationEvent.self, from: context).isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: exportDirectory.path))

        let rules = try fetch(ComplianceRule.self, from: context)
        XCTAssertEqual(rules.count, 1)
        XCTAssertEqual(rules.first?.name, "Default Monthly Rule")
        XCTAssertEqual(rules.first?.jurisdictionId, "AU-VIC")
        XCTAssertEqual(rules.first?.fixedRequiredDays, 10)
        XCTAssertEqual(rules.first?.prorateFixedTargetForLeave, true)

        let holidays = try fetch(PublicHoliday.self, from: context)
        XCTAssertEqual(holidays.count, 1)
        XCTAssertEqual(holidays.first?.name, "Bundled holiday")
        XCTAssertEqual(holidays.first?.isUserEdited, false)
    }

    func testResetOnEmptyStoreCreatesExactlyOneDefaultRuleEachTime() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let exportStore = GeneratedExportStore(directoryURL: temporaryExportDirectory())
        let service = DataManagementService(generatedExportStore: exportStore)

        try service.resetUserData(in: context)
        try service.resetUserData(in: context)

        let rules = try fetch(ComplianceRule.self, from: context)
        XCTAssertEqual(rules.count, 1)
        XCTAssertEqual(rules.first?.country, .australia)
        XCTAssertEqual(rules.first?.selectedISOWeekdays, [1, 2, 3, 4, 5])
        XCTAssertEqual(rules.first?.preferredOfficeISOWeekdays, [])
    }

    func testGeneratedExportStoreRejectsTraversalAndUnmanagedDeletion() throws {
        let parentDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WorkTrackExportStoreTests-\(UUID().uuidString)", isDirectory: true)
        let managedDirectory = parentDirectory
            .appendingPathComponent(GeneratedExportStore.directoryName, isDirectory: true)
        let store = GeneratedExportStore(directoryURL: managedDirectory)
        try FileManager.default.createDirectory(at: parentDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parentDirectory) }

        XCTAssertThrowsError(try store.fileURL(named: "../outside.csv")) { error in
            XCTAssertEqual(error as? GeneratedExportStoreError, .invalidFileName)
        }

        let outsideURL = parentDirectory.appendingPathComponent("outside.csv")
        try Data("outside".utf8).write(to: outsideURL)

        XCTAssertThrowsError(try store.removeFile(at: outsideURL)) { error in
            XCTAssertEqual(error as? GeneratedExportStoreError, .unmanagedFile)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: outsideURL.path))
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            AttendanceDay.self,
            LeaveRecord.self,
            ManualAdjustment.self,
            ComplianceRule.self,
            CustomExcludedDay.self,
            PlannedOfficeDay.self,
            Place.self,
            LocationEvent.self,
            PublicHoliday.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func fetch<Model: PersistentModel>(
        _ modelType: Model.Type,
        from context: ModelContext
    ) throws -> [Model] {
        try context.fetch(FetchDescriptor<Model>())
    }

    private func temporaryExportDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("WorkTrackDataManagementTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent(GeneratedExportStore.directoryName, isDirectory: true)
    }

    private func date(_ isoDate: String) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

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
}
