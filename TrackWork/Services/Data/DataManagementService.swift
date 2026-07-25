import SwiftData

@MainActor
struct DataManagementService {
    private let generatedExportStore: GeneratedExportStore

    init(generatedExportStore: GeneratedExportStore? = nil) {
        self.generatedExportStore = generatedExportStore ?? GeneratedExportStore()
    }

    func resetUserData(in modelContext: ModelContext) throws {
        try generatedExportStore.removeAllFiles()

        do {
            try deleteAll(ManualAdjustment.self, from: modelContext)
            try deleteAll(LocationEvent.self, from: modelContext)
            try deleteAll(LeaveRecord.self, from: modelContext)
            try deleteAll(CustomExcludedDay.self, from: modelContext)
            try deleteAll(PlannedOfficeDay.self, from: modelContext)
            try deleteAll(AttendanceDay.self, from: modelContext)
            try deleteAll(Place.self, from: modelContext)
            try deleteAll(ComplianceRule.self, from: modelContext)
            try deleteUserEditedHolidays(from: modelContext)

            modelContext.insert(ComplianceRule())
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    private func deleteAll<Model: PersistentModel>(
        _ modelType: Model.Type,
        from modelContext: ModelContext
    ) throws {
        let records = try modelContext.fetch(FetchDescriptor<Model>())
        for record in records {
            modelContext.delete(record)
        }
    }

    private func deleteUserEditedHolidays(from modelContext: ModelContext) throws {
        let holidays = try modelContext.fetch(FetchDescriptor<PublicHoliday>())
        for holiday in holidays where holiday.isUserEdited {
            modelContext.delete(holiday)
        }
    }
}
