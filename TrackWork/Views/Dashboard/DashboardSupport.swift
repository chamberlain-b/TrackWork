import Foundation

struct DashboardRuleAdapter {
    let rule: ComplianceRule

    var calculatorRequirement: ComplianceCalculator.Requirement {
        switch rule.requirementType ?? .fixedMonthlyDays {
        case .fixedMonthlyDays:
            return .fixedMonthlyDays(
                baseRequiredDays: rule.fixedRequiredDays ?? 0,
                prorateForLeave: rule.prorateFixedTargetForLeave
            )
        case .percentageOfEligibleDays:
            return .percentageOfEligibleDays(rule.requiredPercentage ?? 0)
        }
    }

    var jurisdictionName: String {
        JurisdictionCatalog.all.first { $0.id == rule.jurisdictionId }?.displayName
            ?? rule.jurisdictionId
    }

    func requirementExplanation(for summary: ComplianceSummary) -> String {
        switch rule.requirementType ?? .fixedMonthlyDays {
        case .fixedMonthlyDays:
            if rule.prorateFixedTargetForLeave {
                return "Your fixed target of \(rule.fixedRequiredDays ?? 0) days is prorated "
                    + "using \(summary.adjustedEligibleDays) of \(summary.baseEligibleDays) eligible workdays."
            }

            return "Your fixed target is not adjusted when leave reduces the number of eligible workdays."
        case .percentageOfEligibleDays:
            let percentage = rule.requiredPercentage ?? 0
            let formattedPercentage = percentage.formatted(.percent.precision(.fractionLength(0...1)))
            return "Your target is \(formattedPercentage) of \(summary.adjustedEligibleDays) eligible workdays "
                + "after holidays and leave."
        }
    }
}

enum DashboardDataAdapter {
    static func leaveRecord(_ leaveRecord: LeaveRecord) -> ComplianceCalculator.LeaveRecord? {
        guard let leaveType = leaveRecord.leaveType,
              let duration = leaveRecord.duration else {
            return nil
        }

        return ComplianceCalculator.LeaveRecord(
            date: leaveRecord.date,
            type: leaveType,
            duration: duration
        )
    }

    static func attendanceDay(_ attendanceDay: AttendanceDay) -> ComplianceCalculator.AttendanceDay? {
        guard let finalClassification = attendanceDay.finalClassification else {
            return nil
        }

        return ComplianceCalculator.AttendanceDay(
            date: attendanceDay.date,
            finalClassification: finalClassification,
            officeMinutes: attendanceDay.officeMinutes
        )
    }

    static func leaveRecordSort(_ lhs: LeaveRecord, _ rhs: LeaveRecord) -> Bool {
        lhs.date == rhs.date ? lhs.leaveTypeRaw < rhs.leaveTypeRaw : lhs.date < rhs.date
    }
}

extension Calendar {
    static var dashboardCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = .autoupdatingCurrent
        calendar.timeZone = .autoupdatingCurrent
        calendar.firstWeekday = 2
        return calendar
    }

    func dashboardMonthStart(for date: Date) -> Date {
        dateInterval(of: .month, for: date)?.start ?? startOfDay(for: date)
    }

    func dashboardMonthEnd(for date: Date) -> Date {
        guard let monthInterval = dateInterval(of: .month, for: date),
              let finalDate = self.date(byAdding: .day, value: -1, to: monthInterval.end) else {
            return startOfDay(for: date)
        }

        return startOfDay(for: finalDate)
    }

    func isDate(_ date: Date, inSameDashboardMonthAs referenceDate: Date) -> Bool {
        let components = dateComponents([.year, .month], from: date)
        let referenceComponents = dateComponents([.year, .month], from: referenceDate)
        return components.year == referenceComponents.year && components.month == referenceComponents.month
    }
}
