import Foundation
import SwiftData

@Model
final class LeaveRecord {
    @Attribute(.unique) var id: UUID
    var date: Date
    var leaveTypeRaw: String
    var durationRaw: String
    var note: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        date: Date,
        leaveType: LeaveType,
        duration: LeaveDuration = .fullDay,
        note: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.date = date
        self.leaveTypeRaw = leaveType.rawValue
        self.durationRaw = duration.rawValue
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension LeaveRecord {
    var leaveType: LeaveType? {
        LeaveType(rawValue: leaveTypeRaw)
    }

    var duration: LeaveDuration? {
        LeaveDuration(rawValue: durationRaw)
    }
}
