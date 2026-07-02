import Foundation
import SwiftData

@Model
final class ComplianceRule {
    @Attribute(.unique) var id: UUID
    var name: String
    var countryCode: String
    var jurisdictionId: String
    var requirementTypeRaw: String
    var fixedRequiredDays: Int?
    var requiredPercentage: Double?
    var prorateFixedTargetForLeave: Bool
    var minimumOfficeMinutes: Int
    var selectedISOWeekdays: [Int]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String = "Default Monthly Rule",
        country: Country = .australia,
        jurisdictionId: String = "AU-VIC",
        requirementType: RequirementType = .fixedMonthlyDays,
        fixedRequiredDays: Int? = 10,
        requiredPercentage: Double? = nil,
        prorateFixedTargetForLeave: Bool = true,
        minimumOfficeMinutes: Int = 180,
        selectedISOWeekdays: [Int] = [1, 2, 3, 4, 5],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.countryCode = country.rawValue
        self.jurisdictionId = jurisdictionId
        self.requirementTypeRaw = requirementType.rawValue
        self.fixedRequiredDays = fixedRequiredDays
        self.requiredPercentage = requiredPercentage
        self.prorateFixedTargetForLeave = prorateFixedTargetForLeave
        self.minimumOfficeMinutes = minimumOfficeMinutes
        self.selectedISOWeekdays = selectedISOWeekdays
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension ComplianceRule {
    var country: Country? {
        Country(rawValue: countryCode)
    }

    var requirementType: RequirementType? {
        RequirementType(rawValue: requirementTypeRaw)
    }
}
