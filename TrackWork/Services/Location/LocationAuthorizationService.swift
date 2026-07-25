import CoreLocation
import Observation

@MainActor
@Observable
final class LocationAuthorizationService: NSObject {
    private let locationManager: CLLocationManager
    private var shouldRequestLocationAfterAuthorization = false

    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var isRequestingLocation = false
    private(set) var currentLocation: CLLocation?
    private(set) var locationUpdateID = 0
    private(set) var errorMessage: String?

    init(locationManager: CLLocationManager = CLLocationManager()) {
        self.locationManager = locationManager
        self.authorizationStatus = locationManager.authorizationStatus
        super.init()
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var isPermissionDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = locationManager.authorizationStatus
    }

    func requestCurrentLocation() {
        refreshAuthorizationStatus()
        errorMessage = nil
        currentLocation = nil
        isRequestingLocation = true

        switch authorizationStatus {
        case .notDetermined:
            shouldRequestLocationAfterAuthorization = true
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            requestOneLocationFix()
        case .denied:
            finishWithError("Location access is off. You can enable it in iOS Settings or choose an address instead.")
        case .restricted:
            finishWithError(
                "Location access is restricted on this device. Choose an address or a point on the map instead."
            )
        @unknown default:
            finishWithError("Current location is unavailable. Choose an address or a point on the map instead.")
        }
    }

    func discardCurrentLocation() {
        currentLocation = nil
    }

    private func requestOneLocationFix() {
        shouldRequestLocationAfterAuthorization = false

        if let uiTestCurrentLocation {
            publishCurrentLocation(uiTestCurrentLocation)
            return
        }

        locationManager.requestLocation()
    }

    private var uiTestCurrentLocation: CLLocation? {
        guard AppLaunchConfiguration.isUITesting,
              ProcessInfo.processInfo.environment["TRACKWORK_UI_TEST_CURRENT_LOCATION"] == "1"
        else {
            return nil
        }

        return CLLocation(latitude: -37.8136, longitude: 144.9631)
    }

    private func publishCurrentLocation(_ location: CLLocation) {
        guard isRequestingLocation else {
            return
        }

        currentLocation = location
        locationUpdateID += 1
        isRequestingLocation = false
        errorMessage = nil
    }

    private func finishWithError(_ message: String) {
        shouldRequestLocationAfterAuthorization = false
        isRequestingLocation = false
        errorMessage = message
    }
}

extension LocationAuthorizationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus

            guard shouldRequestLocationAfterAuthorization else {
                return
            }

            switch authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                requestOneLocationFix()
            case .denied:
                finishWithError(
                    "Location access was not allowed. Choose an address instead, or enable access in iOS Settings."
                )
            case .restricted:
                finishWithError("Location access is restricted on this device. Choose an address instead.")
            case .notDetermined:
                break
            @unknown default:
                finishWithError("Current location is unavailable. Choose an address instead.")
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            return
        }

        Task { @MainActor in
            publishCurrentLocation(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            guard isRequestingLocation else {
                return
            }

            finishWithError("Your current location could not be determined. Try again or search for an address.")
        }
    }
}
