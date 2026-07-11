import Foundation

enum ComplianceTreatmentResolver {
    static func resolve(
        classification: AttendanceClassification,
        officeMinutes: Int,
        minimumOfficeMinutes: Int
    ) -> ComplianceTreatment {
        switch classification {
        case .office:
            .countsAsOffice
        case .mixed:
            officeMinutes >= max(0, minimumOfficeMinutes) ? .countsAsOffice : .countsAsHome
        case .home:
            .countsAsHome
        case .annualLeave, .sickLeave, .publicHoliday, .weekend, .nonWorkingDay:
            .excludedFromRequirement
        case .unknown:
            .requiresReview
        }
    }
}
