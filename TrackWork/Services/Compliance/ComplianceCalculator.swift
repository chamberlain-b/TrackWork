import Foundation

struct ComplianceCalculator {
    struct Input {
        let periodStart: Date
        let periodEnd: Date
        let calendar: Calendar
        let selectedISOWeekdays: Set<Int>
        let publicHolidays: Set<Date>
        let leaveRecords: [LeaveRecord]
        let attendanceDays: [AttendanceDay]
        let requirement: Requirement
    }

    struct LeaveRecord {
        let date: Date
        let type: LeaveType
        let duration: LeaveDuration
    }

    struct AttendanceDay {
        let date: Date
        let finalClassification: AttendanceClassification
        let officeMinutes: Int
    }

    enum Requirement {
        case percentageOfEligibleDays(Double)
        case fixedMonthlyDays(baseRequiredDays: Int, prorateForLeave: Bool)
    }

    struct Summary: Equatable {
        let baseEligibleDays: Int
        let adjustedEligibleDays: Int
        let requiredOfficeDays: Int
        let completedOfficeDays: Int
        let reviewRequiredDays: Int
    }

    enum PendingImplementationError: Error, Equatable {
        case notImplemented
    }

    /// Placeholder API for the leave-adjusted compliance calculator milestone.
    /// The implementation is intentionally pending so tests can define the expected contract first.
    func calculate(_ input: Input) throws -> Summary {
        throw PendingImplementationError.notImplemented
    }
}
