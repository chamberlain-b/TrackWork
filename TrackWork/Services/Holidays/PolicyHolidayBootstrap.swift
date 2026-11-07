import Foundation
import SwiftData

/// Loads calendars only for policies the user has saved. An empty store remains unconfigured.
@MainActor
struct PolicyHolidayBootstrap {
    struct Selection: Hashable {
        let countryCode: String
        let jurisdictionId: String
    }

    private let syncService: HolidaySyncService

    init(syncService: HolidaySyncService? = nil) {
        self.syncService = syncService ?? HolidaySyncService()
    }

    static func selections(for rules: [ComplianceRule]) -> [Selection] {
        // Older policy regions are still needed when viewing historical attendance.
        Set(rules.map { Selection(countryCode: $0.countryCode, jurisdictionId: $0.jurisdictionId) })
            .sorted {
                if $0.countryCode != $1.countryCode {
                    return $0.countryCode < $1.countryCode
                }
                return $0.jurisdictionId < $1.jurisdictionId
            }
    }

    /// The returned message reports coverage limits without changing any policy or attendance record.
    func sync(
        policies: [ComplianceRule],
        in modelContext: ModelContext,
        now: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) throws -> String? {
        let selections = Self.selections(for: policies)
        guard !selections.isEmpty else { return nil }

        for selection in selections {
            guard let country = Country(rawValue: selection.countryCode) else {
                throw HolidayProviderError.unsupportedJurisdiction(
                    countryCode: selection.countryCode,
                    jurisdictionId: selection.jurisdictionId
                )
            }
            try syncService.sync(
                country: country,
                jurisdictionId: selection.jurisdictionId,
                years: HolidayCoverage.supportedYears,
                in: modelContext
            )
        }

        return HolidayCoverage.validation(forYear: calendar.component(.year, from: now)).userFacingMessage
    }
}
