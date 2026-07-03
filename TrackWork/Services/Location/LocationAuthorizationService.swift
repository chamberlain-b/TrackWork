import CoreLocation
import Observation

@MainActor
@Observable
final class LocationAuthorizationService: NSObject {
    private let locationManager: CLLocationManager

    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var isRequestingAuthorization = false

    let automaticBackgroundTrackingEnabled: Bool

    init(locationManager: CLLocationManager = CLLocationManager(), automaticBackgroundTrackingEnabled: Bool = false) {
        self.locationManager = locationManager
        self.authorizationStatus = locationManager.authorizationStatus
        self.automaticBackgroundTrackingEnabled = automaticBackgroundTrackingEnabled
        super.init()
        self.locationManager.delegate = self
    }

    var canRequestWhenInUseAuthorization: Bool {
        authorizationStatus == .notDetermined
    }

    var canRequestAlwaysAuthorization: Bool {
        automaticBackgroundTrackingEnabled && authorizationStatus == .authorizedWhenInUse
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = locationManager.authorizationStatus
    }

    func requestWhenInUseAuthorization() {
        refreshAuthorizationStatus()

        guard canRequestWhenInUseAuthorization else {
            return
        }

        isRequestingAuthorization = true
        locationManager.requestWhenInUseAuthorization()
    }

    func requestAlwaysAuthorizationIfAvailable() {
        refreshAuthorizationStatus()

        guard canRequestAlwaysAuthorization else {
            return
        }

        isRequestingAuthorization = true
        locationManager.requestAlwaysAuthorization()
    }
}

extension LocationAuthorizationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            isRequestingAuthorization = false
        }
    }
}
