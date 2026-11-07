import Foundation
import SwiftData

enum AppLaunchConfiguration {
    enum UITestFixture: String {
        case adaptivePlan
        case approvedHome
        case fresh
        case firstLaunch
        case existingPolicyUpgrade
        case phoneHome
        case phoneOffice
        case phoneUnrecorded
        case planCovered
        case planShortfall
        case populated
        case summaryReview
        case variation3
        case variation3LeaveHeavy
        case variation3Overrides
        case variation3Empty
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

    static var shouldBootstrapHolidays: Bool {
        // Setup and upgrade tests run production policy/holiday startup against an in-memory store.
        // Location services continue to use the separate isUITesting guard, avoiding OS side effects.
        !isUITesting || [.firstLaunch, .existingPolicyUpgrade].contains(uiTestFixture)
    }

    static var dashboardReferenceDate: Date {
        guard isUITesting else {
            return .now
        }

        switch uiTestFixture {
        case .adaptivePlan, .planCovered, .planShortfall, .summaryReview, .variation3, .variation3LeaveHeavy, .variation3Overrides, .variation3Empty:
            return fixedUITestReferenceDate
        case .approvedHome:
            return approvedHomeReferenceDate
        case .phoneHome, .phoneOffice, .phoneUnrecorded:
            return phoneHomeReferenceDate
        case .fresh, .firstLaunch, .existingPolicyUpgrade, .populated:
            return .now
        }
    }

    private static var approvedHomeReferenceDate: Date {
        let calendar = Calendar.workTrackCalendar
        return calendar.date(from: DateComponents(year: 2026, month: 10, day: 3, hour: 12)) ?? .now
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
        // Exercise the actual unconfigured setup state without touching an on-disk store.
        guard fixture != .firstLaunch else { return }
        if fixture == .existingPolicyUpgrade {
            try insertExistingPolicyUpgradeFixture(in: modelContext)
            return
        }
        let fixedRequiredDays = [.adaptivePlan, .approvedHome, .planCovered, .planShortfall].contains(fixture) ? 8 : 10
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
        case .firstLaunch, .existingPolicyUpgrade:
            return
        case .approvedHome:
            insertApprovedHomeFixture(in: modelContext)
            try modelContext.save()
        case .adaptivePlan:
            insertPlanCoveredFixture(in: modelContext)
            insertAdaptivePlanFixture(in: modelContext)
            try modelContext.save()
        case .fresh, .variation3Empty, .phoneHome, .phoneOffice, .phoneUnrecorded:
            insertPhoneHomeFixtureIfNeeded(fixture, in: modelContext)
            try modelContext.save()
        case .variation3, .variation3LeaveHeavy, .variation3Overrides:
            insertVariation3Fixture(fixture, in: modelContext)
            try modelContext.save()
        case .planCovered:
            insertPlanCoveredFixture(in: modelContext)
            try modelContext.save()
        case .planShortfall:
            insertPlanShortfallFixture(in: modelContext)
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

    private static func insertExistingPolicyUpgradeFixture(in modelContext: ModelContext) throws {
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: AppLaunchConfiguration.dashboardReferenceDate)
        let originalDate = calendar.date(byAdding: .month, value: -3, to: today) ?? today
        modelContext.insert(ComplianceRule(
            name: "Existing NSW policy",
            country: .australia,
            jurisdictionId: "AU-NSW",
            fixedRequiredDays: 7,
            minimumOfficeMinutes: 240,
            selectedISOWeekdays: [1, 2, 3, 4],
            preferredOfficeISOWeekdays: [2],
            createdAt: originalDate,
            updatedAt: originalDate
        ))
        modelContext.insert(AttendanceDay(
            date: today,
            detectedClassification: .home,
            finalClassification: .office,
            manualClassification: .office,
            complianceTreatment: .countsAsOffice,
            officeMinutes: 420,
            homeMinutes: 60,
            note: "Existing attendance note",
            createdAt: originalDate,
            updatedAt: originalDate
        ))
        try modelContext.save()
    }

    private static func insertApprovedHomeFixture(in modelContext: ModelContext) {
        // October has one office day and one home day: 50% recorded-workday share,
        // independently of one completed day against the eight-day office target.
        let records: [(month: Int, day: Int, status: AttendanceClassification)] = [
            (9, 28, .office), (9, 29, .home), (9, 30, .office),
            (10, 1, .home), (10, 2, .office)
        ]
        for record in records {
            let isOffice = record.status == .office
            modelContext.insert(AttendanceDay(
                date: uiTestDate(year: 2026, month: record.month, day: record.day),
                detectedClassification: record.status,
                finalClassification: record.status,
                complianceTreatment: isOffice ? .countsAsOffice : .countsAsHome,
                officeMinutes: isOffice ? 420 : 0,
                homeMinutes: isOffice ? 0 : 420
            ))
        }
    }

    private static func insertVariation3Fixture(
        _ fixture: AppLaunchConfiguration.UITestFixture, in modelContext: ModelContext
    ) {
        let calendar = Calendar.workTrackCalendar
        let referenceDate = AppLaunchConfiguration.dashboardReferenceDate
        for month in 2...7 {
            for day in 1...28 {
                let date = uiTestDate(year: 2026, month: month, day: day)
                guard !calendar.isDateInWeekend(date), date <= referenceDate else { continue }
                // Include a zero-office month and short, mixed and dense histories.
                let status: AttendanceClassification = month == 3 ? .home : day % 5 == 0 ? .mixed : day % 3 == 0 ? .home : .office
                let isOverride = fixture == .variation3Overrides && day % 2 == 0
                let officeMinutes = status == .mixed ? 200 : status == .office ? 420 : 0
                let isLeave = fixture == .variation3LeaveHeavy && day % 3 != 0
                let isExcluded = isLeave || (month == 7 && [10, 13].contains(day))
                let record = AttendanceDay(
                    date: date, detectedClassification: isOverride ? .home : status,
                    finalClassification: status, manualClassification: isOverride ? status : nil,
                    complianceTreatment: isExcluded ? .excludedFromRequirement : ComplianceTreatmentResolver.resolve(
                        classification: status, officeMinutes: officeMinutes, minimumOfficeMinutes: 180
                    ),
                    officeMinutes: officeMinutes,
                    homeMinutes: status == .mixed ? 220 : status == .home ? 420 : 0,
                    note: isOverride ? "Corrected attendance" : nil
                )
                modelContext.insert(record)
                if isOverride {
                    modelContext.insert(ManualAdjustment(attendanceDayId: record.id,
                        adjustedClassification: status, reason: .forgotWorkPass, note: "Corrected attendance"))
                }
                if isLeave {
                    modelContext.insert(LeaveRecord(date: date, leaveType: day % 2 == 0 ? .annualLeave : .sickLeave))
                }
            }
        }
        modelContext.insert(PublicHoliday(date: uiTestDate(year: 2026, month: 7, day: 10),
            name: "Fixture holiday", country: .australia, jurisdictionId: "AU-VIC",
            isRegional: false, sourceName: "Visual test fixture"))
        modelContext.insert(CustomExcludedDay(date: uiTestDate(year: 2026, month: 7, day: 13)))
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

    private static func insertPlanShortfallFixture(in modelContext: ModelContext) {
        let pastWorkdays = uiTestPastWorkdays()
        let completedDates = Set(pastWorkdays.suffix(7))

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
