import Foundation
import SwiftData

extension AppLaunchConfiguration {
    static var phoneHomeReferenceDate: Date {
        let calendar = Calendar.workTrackCalendar
        return calendar.date(from: DateComponents(year: 2026, month: 11, day: 6, hour: 12)) ?? .now
    }
}

extension AppModelContainer {
    static func insertPhoneHomeFixtureIfNeeded(
        _ fixture: AppLaunchConfiguration.UITestFixture,
        in modelContext: ModelContext
    ) {
        guard [.phoneHome, .phoneOffice, .phoneUnrecorded].contains(fixture) else { return }
        // Match the approved phone reference without reading or changing a personal store.
        modelContext.insert(LeaveRecord(date: phoneFixtureDate(2), leaveType: .annualLeave))
        modelContext.insert(PublicHoliday(
            date: phoneFixtureDate(3),
            name: "Melbourne Cup Day",
            country: .australia,
            jurisdictionId: "AU-VIC",
            isRegional: false,
            sourceName: "UI Test Fixture"
        ))
        let todayStatus: AttendanceClassification? = switch fixture {
        case .phoneHome: .home
        case .phoneOffice: .office
        default: nil
        }
        var records: [(day: Int, status: AttendanceClassification)] = [(4, .home), (5, .office)]
        if let todayStatus {
            records.append((6, todayStatus))
        }
        for record in records {
            let isOffice = record.status == .office
            modelContext.insert(AttendanceDay(
                date: phoneFixtureDate(record.day),
                detectedClassification: record.status,
                finalClassification: record.status,
                complianceTreatment: isOffice ? .countsAsOffice : .countsAsHome,
                officeMinutes: isOffice ? 420 : 0,
                homeMinutes: isOffice ? 0 : 420
            ))
        }
    }

    private static func phoneFixtureDate(_ day: Int) -> Date {
        let calendar = Calendar.workTrackCalendar
        return calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: 12)) ?? .now
    }
}
