import Foundation
import SwiftData

enum AppLaunchConfiguration {
    enum UITestFixture: String {
        case adaptivePlan
        case fresh
        case planCovered
        case populated
        case summaryReview
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

    static var dashboardReferenceDate: Date {
        guard isUITesting else {
            return .now
        }

        switch uiTestFixture {
        case .adaptivePlan, .planCovered, .summaryReview:
            return fixedUITestReferenceDate
        case .fresh, .populated:
            return .now
        }
    }

    private static var fixedUITestReferenceDate: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = 2026
        components.month = 7
        components.day = 29
        components.hour = 12
        return calendar.date(from: components) ?? .now
    }
}

@MainActor
enum AppModelContainer {
    static func make() -> ModelContainer {
        if AppLaunchConfiguration.isUITesting {
            UserDefaults.standard.removeObject(forKey: "calendar.displayMode")
        }

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
        let fixedRequiredDays = [.adaptivePlan, .planCovered].contains(fixture) ? 8 : 10
        let rule = ComplianceRule(
            name: "UI Test Rule",
            country: .australia,
            jurisdictionId: "AU-VIC",
            requirementType: .fixedMonthlyDays,
            fixedRequiredDays: fixedRequiredDays,
            prorateFixedTargetForLeave: true,
            minimumOfficeMinutes: 180,
            selectedISOWeekdays: [1, 2, 3, 4, 5],
            preferredOfficeISOWeekdays: fixture == .adaptivePlan ? [3] : []
        )
        modelContext.insert(rule)

        switch fixture {
        case .adaptivePlan:
            insertPlanCoveredFixture(in: modelContext)
            insertAdaptivePlanFixture(in: modelContext)
            try modelContext.save()
        case .fresh:
            try modelContext.save()
        case .planCovered:
            insertPlanCoveredFixture(in: modelContext)
            try modelContext.save()
        case .populated:
            let date = uiTestDate()
            insertManuallyCorrectedOfficeDay(on: date, in: modelContext)
            insertPopulatedLocationFixture(on: date, in: modelContext)
            try modelContext.save()
        case .summaryReview:
            insertSummaryReviewFixture(in: modelContext)
            try modelContext.save()
        }
    }

    private static func insertAdaptivePlanFixture(in modelContext: ModelContext) {
        [
            uiTestDate(year: 2026, month: 8, day: 3),
            uiTestDate(year: 2026, month: 8, day: 13),
            uiTestDate(year: 2026, month: 8, day: 19),
            uiTestDate(year: 2026, month: 8, day: 21),
            uiTestDate(year: 2026, month: 8, day: 24),
            uiTestDate(year: 2026, month: 8, day: 31)
        ]
        .forEach { modelContext.insert(PlannedOfficeDay(date: $0)) }

        modelContext.insert(
            LeaveRecord(
                date: uiTestDate(year: 2026, month: 8, day: 11),
                leaveType: .annualLeave,
                note: "UI test planned leave"
            )
        )
        modelContext.insert(
            PublicHoliday(
                date: uiTestDate(year: 2026, month: 8, day: 28),
                name: "UI Test Public Holiday",
                country: .australia,
                jurisdictionId: "AU-VIC",
                isRegional: true,
                sourceName: "UI Test Fixture"
            )
        )
    }

    private static func insertManuallyCorrectedOfficeDay(
        on date: Date,
        in modelContext: ModelContext
    ) {
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
    }

    private static func insertSummaryReviewFixture(in modelContext: ModelContext) {
        let calendar = Calendar.autoupdatingCurrent
        let referenceDate = AppLaunchConfiguration.dashboardReferenceDate
        guard let attendanceDate = calendar.date(
            byAdding: .day,
            value: -1,
            to: referenceDate
        ) else {
            return
        }

        insertManuallyCorrectedOfficeDay(on: attendanceDate, in: modelContext)
        if let plannedDate = uiTestPlannedOfficeDate(referenceDate: referenceDate) {
            modelContext.insert(PlannedOfficeDay(date: plannedDate))
        }
    }

    private static func insertPlanCoveredFixture(in modelContext: ModelContext) {
        let pastWorkdays = uiTestPastWorkdays()
        let plannedDate = uiTestPlannedOfficeDate(
            referenceDate: AppLaunchConfiguration.dashboardReferenceDate
        )
        let target = 8
        let completedCount = plannedDate == nil ? target : max(0, target - 1)
        let completedDates = Set(pastWorkdays.suffix(completedCount))

        for date in pastWorkdays {
            let isOfficeDay = completedDates.contains(date)
            modelContext.insert(
                AttendanceDay(
                    date: date,
                    detectedClassification: isOfficeDay ? .office : .home,
                    finalClassification: isOfficeDay ? .office : .home,
                    complianceTreatment: isOfficeDay ? .countsAsOffice : .countsAsHome,
                    officeMinutes: isOfficeDay ? 420 : 0,
                    homeMinutes: isOfficeDay ? 0 : 420
                )
            )
        }

        if let plannedDate {
            modelContext.insert(PlannedOfficeDay(date: plannedDate))
        }
    }

    private static func uiTestPastWorkdays() -> [Date] {
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: AppLaunchConfiguration.dashboardReferenceDate)
        guard let monthStart = calendar.dateInterval(of: .month, for: today)?.start else {
            return []
        }

        var dates: [Date] = []
        var candidate = calendar.startOfDay(for: monthStart)
        while candidate < today {
            if !calendar.isDateInWeekend(candidate) {
                dates.append(candidate)
            }
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: candidate) else {
                break
            }
            candidate = nextDate
        }
        return dates
    }

    private static func uiTestPlannedOfficeDate(referenceDate: Date = .now) -> Date? {
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: referenceDate)
        let month = calendar.component(.month, from: today)
        let year = calendar.component(.year, from: today)
        var candidate = calendar.date(byAdding: .day, value: 1, to: today)

        while let date = candidate,
              calendar.component(.month, from: date) == month,
              calendar.component(.year, from: date) == year {
            if !calendar.isDateInWeekend(date) {
                return date
            }
            candidate = calendar.date(byAdding: .day, value: 1, to: date)
        }

        return nil
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

    private static func uiTestDate(year: Int, month: Int, day: Int) -> Date {
        let calendar = Calendar.autoupdatingCurrent
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return calendar.date(from: components) ?? .now
    }

}
