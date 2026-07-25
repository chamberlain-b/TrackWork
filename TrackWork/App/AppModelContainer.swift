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
            PlannedOfficeDay.self,
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
        insertPopulatedLocationFixture(on: date, in: modelContext)
        try modelContext.save()
    }

    private static func insertPopulatedLocationFixture(on date: Date, in modelContext: ModelContext) {
        let office = Place(
            name: "UI Test Office",
            type: .office,
            latitude: -37.8136,
            longitude: 144.9631,
            formattedAddress: "Melbourne VIC, Australia"
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
        if let plannedDate = uiTestPlannedOfficeDate() {
            modelContext.insert(PlannedOfficeDay(date: plannedDate))
        }
    }

    private static func uiTestDate() -> Date {
        let calendar = Calendar.autoupdatingCurrent
        var date = calendar.startOfDay(for: .now)
        let month = calendar.component(.month, from: date)
        let year = calendar.component(.year, from: date)

        while calendar.isDateInWeekend(date) {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: date) else {
                break
            }

            guard calendar.component(.month, from: previous) == month,
                  calendar.component(.year, from: previous) == year else {
                break
            }

            date = previous
        }

        return date
    }

    private static func uiTestPlannedOfficeDate() -> Date? {
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: .now)
        let month = calendar.component(.month, from: today)
        let year = calendar.component(.year, from: today)
        var candidate = calendar.date(byAdding: .day, value: 1, to: today)

        while let date = candidate,
              calendar.component(.month, from: date) == month,
              calendar.component(.year, from: date) == year {
            if (2...6).contains(calendar.component(.weekday, from: date)) {
                return date
            }
            candidate = calendar.date(byAdding: .day, value: 1, to: date)
        }

        return nil
    }
}
