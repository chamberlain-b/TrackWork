import Foundation

/// Editable values only. Opening or cancelling the editor never inserts a policy.
struct WorkPolicyDraft: Equatable {
    var country: Country
    var jurisdictionId: String
    var requirementType: RequirementType
    var fixedRequiredDays: Int
    /// The fraction of eligible workdays, from zero to one.
    var requiredPercentage: Double
    var prorateFixedTargetForLeave: Bool
    var minimumOfficeMinutes: Int
    var selectedISOWeekdays: [Int]
    var preferredOfficeISOWeekdays: [Int]

    init(rule: ComplianceRule? = nil) {
        country = rule?.country ?? .australia
        jurisdictionId = rule?.jurisdictionId ?? "AU-VIC"
        requirementType = rule?.requirementType ?? .fixedMonthlyDays
        fixedRequiredDays = rule?.fixedRequiredDays ?? 10
        requiredPercentage = rule?.requiredPercentage ?? 0.5
        prorateFixedTargetForLeave = rule?.prorateFixedTargetForLeave ?? true
        minimumOfficeMinutes = rule?.minimumOfficeMinutes ?? 180
        selectedISOWeekdays = rule?.selectedISOWeekdays ?? [1, 2, 3, 4, 5]
        preferredOfficeISOWeekdays = rule?.preferredOfficeISOWeekdays ?? []
    }

    var validationMessage: String? {
        if requirementType == .fixedMonthlyDays && fixedRequiredDays < 0 {
            return "Enter an office target of zero days or more."
        }
        if requirementType == .percentageOfEligibleDays &&
            (!requiredPercentage.isFinite || !(0...1).contains(requiredPercentage)) {
            return "Enter an office target between 0% and 100%."
        }
        if selectedISOWeekdays.isEmpty || selectedISOWeekdays.contains(where: { !(1...7).contains($0) }) {
            return "Choose at least one valid workday."
        }
        if preferredOfficeISOWeekdays.contains(where: { !selectedISOWeekdays.contains($0) }) {
            return "Preferred office days must also be selected workdays."
        }
        if !JurisdictionCatalog.jurisdictions(for: country).contains(where: { $0.id == jurisdictionId }) {
            return "Choose a region in your selected country."
        }
        if minimumOfficeMinutes < 0 {
            return "Enter a minimum office time of zero minutes or more."
        }
        return nil
    }

    func matches(_ rule: ComplianceRule) -> Bool {
        country == rule.country &&
        jurisdictionId == rule.jurisdictionId &&
        requirementType == rule.requirementType &&
        (requirementType != .fixedMonthlyDays || fixedRequiredDays == rule.fixedRequiredDays) &&
        (requirementType != .percentageOfEligibleDays || requiredPercentage == rule.requiredPercentage) &&
        prorateFixedTargetForLeave == rule.prorateFixedTargetForLeave &&
        minimumOfficeMinutes == rule.minimumOfficeMinutes &&
        Set(selectedISOWeekdays) == Set(rule.selectedISOWeekdays) &&
        Set(preferredOfficeISOWeekdays) == Set(rule.preferredOfficeISOWeekdays)
    }

    func apply(to rule: ComplianceRule, now: Date) {
        rule.countryCode = country.rawValue
        rule.jurisdictionId = jurisdictionId
        rule.requirementTypeRaw = requirementType.rawValue
        rule.fixedRequiredDays = requirementType == .fixedMonthlyDays ? fixedRequiredDays : nil
        rule.requiredPercentage = requirementType == .percentageOfEligibleDays ? requiredPercentage : nil
        rule.prorateFixedTargetForLeave = prorateFixedTargetForLeave
        rule.minimumOfficeMinutes = minimumOfficeMinutes
        rule.selectedISOWeekdays = Set(selectedISOWeekdays).sorted()
        rule.preferredOfficeISOWeekdays = Set(preferredOfficeISOWeekdays).sorted()
        rule.updatedAt = now
    }
}
