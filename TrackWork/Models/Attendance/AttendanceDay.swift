import Foundation
import SwiftData

@Model
final class AttendanceDay {
    @Attribute(.unique) var id: UUID
    var date: Date
    var detectedClassificationRaw: String
    var finalClassificationRaw: String
    var manualClassificationRaw: String?
    var complianceTreatmentRaw: String
    var officeMinutes: Int
    var homeMinutes: Int
    var note: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        date: Date,
        detectedClassification: AttendanceClassification = .unknown,
        finalClassification: AttendanceClassification = .unknown,
        manualClassification: AttendanceClassification? = nil,
        complianceTreatment: ComplianceTreatment = .requiresReview,
        officeMinutes: Int = 0,
        homeMinutes: Int = 0,
        note: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.date = date
        self.detectedClassificationRaw = detectedClassification.rawValue
        self.finalClassificationRaw = finalClassification.rawValue
        self.manualClassificationRaw = manualClassification?.rawValue
        self.complianceTreatmentRaw = complianceTreatment.rawValue
        self.officeMinutes = officeMinutes
        self.homeMinutes = homeMinutes
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension AttendanceDay {
    var detectedClassification: AttendanceClassification? {
        AttendanceClassification(rawValue: detectedClassificationRaw)
    }

    var finalClassification: AttendanceClassification? {
        AttendanceClassification(rawValue: finalClassificationRaw)
    }

    var manualClassification: AttendanceClassification? {
        guard let manualClassificationRaw else {
            return nil
        }

        return AttendanceClassification(rawValue: manualClassificationRaw)
    }

    var complianceTreatment: ComplianceTreatment? {
        ComplianceTreatment(rawValue: complianceTreatmentRaw)
    }

    func applyManualEdit(
        finalClassification: AttendanceClassification,
        note: String?,
        updatedAt: Date = .now
    ) {
        finalClassificationRaw = finalClassification.rawValue
        manualClassificationRaw = finalClassification.rawValue
        self.note = note?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.updatedAt = updatedAt
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
