import SwiftData
import SwiftUI

struct AppRouter: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Place.typeRaw) private var places: [Place]
    @State private var locationTrackingService = LocationTrackingService()

    @MainActor
    private var placeMonitoringSignature: [PlaceMonitoringSignature] {
        places.map(PlaceMonitoringSignature.init)
    }

    var body: some View {
        ContentView()
            .environment(locationTrackingService)
            .task {
                locationTrackingService.configure(modelContext: modelContext)
                locationTrackingService.refreshMonitoring(for: places)
            }
            .onChange(of: placeMonitoringSignature) { _, _ in
                locationTrackingService.refreshMonitoring(for: places)
            }
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

#Preview {
    AppRouter()
        .modelContainer(PreviewData.modelContainer())
}
