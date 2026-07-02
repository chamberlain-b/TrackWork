import Foundation
import SwiftData

@Model
final class ManualAdjustment {
    @Attribute(.unique) var id: UUID
    var attendanceDayId: UUID
    var adjustedClassificationRaw: String
    var reasonRaw: String
    var note: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        attendanceDayId: UUID,
        adjustedClassification: AttendanceClassification,
        reason: OverrideReason,
        note: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.attendanceDayId = attendanceDayId
        self.adjustedClassificationRaw = adjustedClassification.rawValue
        self.reasonRaw = reason.rawValue
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension ManualAdjustment {
    var adjustedClassification: AttendanceClassification? {
        AttendanceClassification(rawValue: adjustedClassificationRaw)
    }

    var reason: OverrideReason? {
        OverrideReason(rawValue: reasonRaw)
    }
}
