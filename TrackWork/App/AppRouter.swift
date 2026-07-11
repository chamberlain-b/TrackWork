import SwiftData
import SwiftUI

struct AppRouter: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Place.typeRaw) private var places: [Place]
    @Query(sort: \ComplianceRule.createdAt) private var complianceRules: [ComplianceRule]
    @State private var locationTrackingService = LocationTrackingService()
    @State private var holidaySyncError: String?

    private let holidaySyncService = HolidaySyncService()

    @MainActor
    private var placeMonitoringSignature: [PlaceMonitoringSignature] {
        places.map(PlaceMonitoringSignature.init)
    }

    private var holidayRuleSignature: HolidayRuleSignature {
        let rule = complianceRules.first
        return HolidayRuleSignature(
            countryCode: rule?.countryCode ?? Country.australia.rawValue,
            jurisdictionId: rule?.jurisdictionId ?? "AU-VIC"
        )
    }

    var body: some View {
        ContentView()
            .environment(locationTrackingService)
            .task {
                guard !AppLaunchConfiguration.isUITesting else {
                    return
                }

                locationTrackingService.configure(modelContext: modelContext)
                locationTrackingService.refreshMonitoring(for: places)
            }
            .onChange(of: placeMonitoringSignature) { _, _ in
                guard !AppLaunchConfiguration.isUITesting else {
                    return
                }

                locationTrackingService.refreshMonitoring(for: places)
            }
            .task(id: holidayRuleSignature) {
                guard !AppLaunchConfiguration.isUITesting else {
                    return
                }

                bootstrapHolidays()
            }
            .alert(
                "Holiday data unavailable",
                isPresented: Binding(
                    get: { holidaySyncError != nil },
                    set: { isPresented in
                        if !isPresented {
                            holidaySyncError = nil
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {
                    holidaySyncError = nil
                }
            } message: {
                Text(holidaySyncError ?? "The bundled holiday calendar could not be loaded.")
            }
    }

    private func bootstrapHolidays() {
        let rule = activeRule()
        guard let country = rule.country else {
            holidaySyncError = "The selected country is not supported."
            return
        }

        let year = Calendar.current.component(.year, from: .now)
        do {
            try holidaySyncService.sync(
                country: country,
                jurisdictionId: rule.jurisdictionId,
                years: [year],
                in: modelContext
            )
            holidaySyncError = nil
        } catch {
            holidaySyncError = error.localizedDescription
        }
    }

    private func activeRule() -> ComplianceRule {
        if let rule = complianceRules.first {
            return rule
        }

        let rule = ComplianceRule()
        modelContext.insert(rule)
        try? modelContext.save()
        return rule
    }
}

private struct PlaceMonitoringSignature: Equatable {
    let id: UUID
    let typeRaw: String
    let latitude: Double
    let longitude: Double
    let radiusMeters: Double
    let isActive: Bool

    init(place: Place) {
        self.id = place.id
        self.typeRaw = place.typeRaw
        self.latitude = place.latitude
        self.longitude = place.longitude
        self.radiusMeters = place.radiusMeters
        self.isActive = place.isActive
    }
}

private struct HolidayRuleSignature: Equatable {
    let countryCode: String
    let jurisdictionId: String
}

#Preview {
    AppRouter()
        .modelContainer(PreviewData.modelContainer())
}
