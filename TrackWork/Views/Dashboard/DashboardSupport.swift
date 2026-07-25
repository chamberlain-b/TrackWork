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
                if summary.adjustedEligibleDays < summary.baseEligibleDays {
                    return "Starts at \(rule.fixedRequiredDays ?? 0) office days "
                        + "and adjusts when eligible workdays are reduced."
                }

                return "Fixed at \(rule.fixedRequiredDays ?? 0) office days for the month."
            }

            return "Fixed at \(rule.fixedRequiredDays ?? 0) office days. Leave does not change it."
        case .percentageOfEligibleDays:
            let percentage = rule.requiredPercentage ?? 0
            let formattedPercentage = percentage.formatted(.percent.precision(.fractionLength(0...1)))
            return "\(formattedPercentage) of eligible workdays, rounded up to a whole day."
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
