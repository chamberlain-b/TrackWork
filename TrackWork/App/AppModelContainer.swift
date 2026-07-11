import Foundation
import SwiftData

enum AppLaunchConfiguration {
    enum UITestFixture: String {
        case fresh
        case populated
    }

    static var isUITesting: Bool {
        ProcessInfo.processInfo.environment["TRACKWORK_UI_TESTING"] == "1"
    }

    static var uiTestFixture: UITestFixture {
        guard let value = ProcessInfo.processInfo.environment["TRACKWORK_UI_TEST_FIXTURE"] else {
            return .fresh
        }

        return UITestFixture(rawValue: value) ?? .fresh
    }
}

@MainActor
enum AppModelContainer {
    static func make() -> ModelContainer {
        let schema = Schema([
            AttendanceDay.self,
            LeaveRecord.self,
            ManualAdjustment.self,
            ComplianceRule.self,
            CustomExcludedDay.self,
            Place.self,
            LocationEvent.self,
            PublicHoliday.self
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: AppLaunchConfiguration.isUITesting
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            if AppLaunchConfiguration.isUITesting {
                try seedUITestFixture(AppLaunchConfiguration.uiTestFixture, in: container.mainContext)
            }
            return container
        } catch {
            preconditionFailure("Unable to create Work Track model container: \(error)")
        }
    }

    private static func seedUITestFixture(
        _ fixture: AppLaunchConfiguration.UITestFixture,
        in modelContext: ModelContext
    ) throws {
        let rule = ComplianceRule(
            name: "UI Test Rule",
            country: .australia,
            jurisdictionId: "AU-VIC",
            requirementType: .fixedMonthlyDays,
            fixedRequiredDays: 10,
            prorateFixedTargetForLeave: true,
            minimumOfficeMinutes: 180,
            selectedISOWeekdays: [1, 2, 3, 4, 5]
        )
        modelContext.insert(rule)

        guard fixture == .populated else {
            try modelContext.save()
            return
        }

        let date = uiTestDate()
        let attendanceDay = AttendanceDay(
            date: date,
            detectedClassification: .home,
            finalClassification: .office,
            manualClassification: .office,
            complianceTreatment: .countsAsOffice,
            officeMinutes: 0,
            homeMinutes: 420,
            note: "UI test manual correction"
        )
        modelContext.insert(attendanceDay)
        modelContext.insert(
            ManualAdjustment(
                attendanceDayId: attendanceDay.id,
                adjustedClassification: .office,
                reason: .forgotWorkPass,
                note: "UI test manual correction"
            )
        )

        let office = Place(
            name: "UI Test Office",
            type: .office,
            latitude: -37.8136,
            longitude: 144.9631
        )
        modelContext.insert(office)
        modelContext.insert(
            LocationEvent(
                placeId: office.id,
                placeName: office.name,
                placeType: .office,
                eventKind: .entered,
                regionIdentifier: "worktrack.ui-test.office",
                occurredAt: date
            )
        )

        try modelContext.save()
    }

    private static func uiTestDate() -> Date {
        let calendar = Calendar.autoupdatingCurrent
        var date = calendar.startOfDay(for: .now)
        let month = calendar.component(.month, from: date)

        while calendar.isDateInWeekend(date), calendar.component(.month, from: date) == month {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: date) else {
                break
            }
            date = previous
        }

        return date
    }
}
