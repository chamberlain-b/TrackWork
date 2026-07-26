import Foundation

struct ComplianceRuleResolver {
    func rule(for date: Date, from rules: [ComplianceRule]) -> ComplianceRule? {
        rules
            .filter { effectiveDate(for: $0) <= date }
            .max(by: isEarlierRule)
            ?? rules.min(by: isEarlierRule)
    }

    func currentRule(from rules: [ComplianceRule], now: Date = .now) -> ComplianceRule? {
        rule(for: now, from: rules)
    }

    func ruleEffectiveInMonth(
        containing date: Date,
        from rules: [ComplianceRule],
        calendar: Calendar
    ) -> ComplianceRule? {
        guard let monthStart = calendar.dateInterval(of: .month, for: date)?.start else {
            return nil
        }

        return rules.first { rule in
            guard let effectiveFrom = rule.effectiveFrom else {
                return false
            }
            return calendar.isDate(effectiveFrom, inSameDayAs: monthStart)
        }
    }

    func copy(
        _ rule: ComplianceRule,
        effectiveFrom: Date,
        now: Date = .now
    ) -> ComplianceRule {
        ComplianceRule(
            name: rule.name,
            country: rule.country ?? .australia,
            jurisdictionId: rule.jurisdictionId,
            requirementType: rule.requirementType ?? .fixedMonthlyDays,
            fixedRequiredDays: rule.fixedRequiredDays,
            requiredPercentage: rule.requiredPercentage,
            prorateFixedTargetForLeave: rule.prorateFixedTargetForLeave,
            minimumOfficeMinutes: rule.minimumOfficeMinutes,
            selectedISOWeekdays: rule.selectedISOWeekdays,
            preferredOfficeISOWeekdays: rule.preferredOfficeISOWeekdays,
            effectiveFrom: effectiveFrom,
            createdAt: now,
            updatedAt: now
        )
    }

    private func effectiveDate(for rule: ComplianceRule) -> Date {
        rule.effectiveFrom ?? .distantPast
    }

    private func isEarlierRule(_ lhs: ComplianceRule, _ rhs: ComplianceRule) -> Bool {
        let lhsDate = effectiveDate(for: lhs)
        let rhsDate = effectiveDate(for: rhs)
        if lhsDate != rhsDate {
            return lhsDate < rhsDate
        }
        return lhs.updatedAt < rhs.updatedAt
    }
}
