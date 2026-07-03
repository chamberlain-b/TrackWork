import Foundation
import SwiftData

/// Deterministic sample data for SwiftUI previews and local development only.
enum PreviewData {
    static let sampleMonth = DateInterval(
        start: date(year: 2026, month: 7, day: 1),
        end: date(year: 2026, month: 8, day: 1)
    )

    static let manualNote = "Forgot work pass. Entered via reception."

    static var attendanceDays: [AttendanceDay] {
        [
            AttendanceDay(
                id: fixedUUID("10000000-0000-0000-0000-000000000001"),
                date: date(year: 2026, month: 7, day: 1),
                detectedClassification: .office,
                finalClassification: .office,
                complianceTreatment: .countsAsOffice,
                officeMinutes: 420,
                homeMinutes: 0,
                createdAt: referenceTimestamp,
                updatedAt: referenceTimestamp
            ),
            AttendanceDay(
                id: fixedUUID("10000000-0000-0000-0000-000000000002"),
                date: date(year: 2026, month: 7, day: 2),
                detectedClassification: .home,
                finalClassification: .home,
                complianceTreatment: .countsAsHome,
                officeMinutes: 0,
                homeMinutes: 450,
                createdAt: referenceTimestamp,
                updatedAt: referenceTimestamp
            ),
            AttendanceDay(
                id: fixedUUID("10000000-0000-0000-0000-000000000003"),
                date: date(year: 2026, month: 7, day: 3),
                detectedClassification: .unknown,
                finalClassification: .office,
                manualClassification: .office,
                complianceTreatment: .countsAsOffice,
                officeMinutes: 390,
                homeMinutes: 0,
                note: manualNote,
                createdAt: referenceTimestamp,
                updatedAt: referenceTimestamp
            ),
            AttendanceDay(
                id: fixedUUID("10000000-0000-0000-0000-000000000004"),
                date: date(year: 2026, month: 7, day: 6),
                detectedClassification: .annualLeave,
                finalClassification: .annualLeave,
                complianceTreatment: .excludedFromRequirement,
                createdAt: referenceTimestamp,
                updatedAt: referenceTimestamp
            ),
            AttendanceDay(
                id: fixedUUID("10000000-0000-0000-0000-000000000005"),
                date: date(year: 2026, month: 7, day: 7),
                detectedClassification: .annualLeave,
                finalClassification: .annualLeave,
                complianceTreatment: .excludedFromRequirement,
                createdAt: referenceTimestamp,
                updatedAt: referenceTimestamp
            ),
            AttendanceDay(
                id: fixedUUID("10000000-0000-0000-0000-000000000006"),
                date: date(year: 2026, month: 7, day: 8),
                detectedClassification: .annualLeave,
                finalClassification: .annualLeave,
                complianceTreatment: .excludedFromRequirement,
                createdAt: referenceTimestamp,
                updatedAt: referenceTimestamp
            ),
            AttendanceDay(
                id: fixedUUID("10000000-0000-0000-0000-000000000007"),
                date: date(year: 2026, month: 7, day: 9),
                detectedClassification: .sickLeave,
                finalClassification: .sickLeave,
                complianceTreatment: .excludedFromRequirement,
                createdAt: referenceTimestamp,
                updatedAt: referenceTimestamp
            ),
            AttendanceDay(
                id: fixedUUID("10000000-0000-0000-0000-000000000008"),
                date: date(year: 2026, month: 7, day: 10),
                detectedClassification: .publicHoliday,
                finalClassification: .publicHoliday,
                complianceTreatment: .excludedFromRequirement,
                createdAt: referenceTimestamp,
                updatedAt: referenceTimestamp
            )
        ]
    }

    static var leaveRecords: [LeaveRecord] {
        [
            LeaveRecord(
                id: fixedUUID("20000000-0000-0000-0000-000000000001"),
                date: date(year: 2026, month: 7, day: 6),
                leaveType: .annualLeave,
                createdAt: referenceTimestamp,
                updatedAt: referenceTimestamp
            ),
            LeaveRecord(
                id: fixedUUID("20000000-0000-0000-0000-000000000002"),
                date: date(year: 2026, month: 7, day: 7),
                leaveType: .annualLeave,
                createdAt: referenceTimestamp,
                updatedAt: referenceTimestamp
            ),
            LeaveRecord(
                id: fixedUUID("20000000-0000-0000-0000-000000000003"),
                date: date(year: 2026, month: 7, day: 8),
                leaveType: .annualLeave,
                createdAt: referenceTimestamp,
                updatedAt: referenceTimestamp
            ),
            LeaveRecord(
                id: fixedUUID("20000000-0000-0000-0000-000000000004"),
                date: date(year: 2026, month: 7, day: 9),
                leaveType: .sickLeave,
                createdAt: referenceTimestamp,
                updatedAt: referenceTimestamp
            )
        ]
    }

    static var defaultComplianceRule: ComplianceRule {
        ComplianceRule(
            id: fixedUUID("30000000-0000-0000-0000-000000000001"),
            name: "Preview Monthly Rule",
            country: .australia,
            jurisdictionId: "AU-VIC",
            requirementType: .fixedMonthlyDays,
            fixedRequiredDays: 10,
            requiredPercentage: nil,
            prorateFixedTargetForLeave: true,
            minimumOfficeMinutes: 180,
            selectedISOWeekdays: [1, 2, 3, 4, 5],
            createdAt: referenceTimestamp,
            updatedAt: referenceTimestamp
        )
    }

    static var publicHolidays: [PublicHoliday] {
        [
            PublicHoliday(
                id: fixedUUID("40000000-0000-0000-0000-000000000001"),
                date: date(year: 2026, month: 7, day: 10),
                name: "Sample Public Holiday",
                country: .australia,
                jurisdictionId: "AU-VIC",
                isRegional: false,
                sourceName: "Preview data",
                createdAt: referenceTimestamp,
                updatedAt: referenceTimestamp
            )
        ]
    }

    @MainActor
    static func modelContainer() -> ModelContainer {
        let schema = Schema([
            AttendanceDay.self,
            LeaveRecord.self,
            ManualAdjustment.self,
            ComplianceRule.self,
            Place.self,
            LocationEvent.self,
            PublicHoliday.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            seed(container.mainContext)
            return container
        } catch {
            preconditionFailure("Unable to create preview model container: \(error)")
        }
    }

    @MainActor
    private static func seed(_ context: ModelContext) {
        attendanceDays.forEach(context.insert)
        leaveRecords.forEach(context.insert)
        context.insert(defaultComplianceRule)
        publicHolidays.forEach(context.insert)
    }

    private static let referenceTimestamp = date(year: 2026, month: 7, day: 1)

    private static func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.calendar = previewCalendar
        components.timeZone = previewCalendar.timeZone
        components.year = year
        components.month = month
        components.day = day

        guard let date = previewCalendar.date(from: components) else {
            preconditionFailure("Invalid preview date: \(year)-\(month)-\(day)")
        }

        return date
    }

    private static func fixedUUID(_ value: String) -> UUID {
        guard let uuid = UUID(uuidString: value) else {
            preconditionFailure("Invalid preview UUID: \(value)")
        }

        return uuid
    }

    private static let previewCalendar: Calendar = {
        guard let timeZone = TimeZone(secondsFromGMT: 0) else {
            preconditionFailure("Unable to create UTC time zone for preview data")
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }()
}
