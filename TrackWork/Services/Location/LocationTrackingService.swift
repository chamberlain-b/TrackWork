import CoreLocation
import Observation
import SwiftData

@MainActor
@Observable
final class LocationTrackingService: NSObject {
    enum TrackingStatus: Equatable {
        case idle
        case unavailable(String)
        case permissionNeeded(String)
        case monitoring(Int)
        case failed(String)
    }

    nonisolated static let regionIdentifierPrefix = "worktrack.place"
    nonisolated static let automationPreferenceKey = "location.automaticAttendance.isEnabled"

    private let locationManager: CLLocationManager
    private let defaults: UserDefaults
    private let automationPreferenceKey: String
    private var modelContext: ModelContext?
    private var monitoredPlaceSnapshots: [String: MonitoredPlaceSnapshot] = [:]
    private var lastConfiguredPlaces: [Place] = []
    private var hasConfiguredPlaces = false
    private var pendingRegionEvents: [PendingRegionEvent] = []

    private(set) var isAutomaticTrackingEnabled: Bool
    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var trackingStatus: TrackingStatus = .idle

    init(
        locationManager: CLLocationManager = CLLocationManager(),
        defaults: UserDefaults = .standard,
        automationPreferenceKey: String = LocationTrackingService.automationPreferenceKey,
        automaticBackgroundTrackingEnabled: Bool? = nil,
        isUITesting: Bool? = nil
    ) {
        self.locationManager = locationManager
        self.defaults = defaults
        self.automationPreferenceKey = automationPreferenceKey
        self.authorizationStatus = locationManager.authorizationStatus

        let shouldBypassAutomation = isUITesting ?? AppLaunchConfiguration.isUITesting
        let storedPreference = automaticBackgroundTrackingEnabled
            ?? defaults.bool(forKey: automationPreferenceKey)
        self.isAutomaticTrackingEnabled = storedPreference && !shouldBypassAutomation
        super.init()
        self.locationManager.delegate = self
    }

    var statusDescription: String {
        switch trackingStatus {
        case .idle:
            isAutomaticTrackingEnabled ? "Waiting for active saved places." : "Automatic attendance is off."
        case .unavailable(let message), .permissionNeeded(let message), .failed(let message):
            message
        case .monitoring(let count):
            "Monitoring \(count) saved place\(count == 1 ? "" : "s")."
        }
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        flushPendingRegionEvents()
    }

    func refreshMonitoring(for places: [Place]) {
        lastConfiguredPlaces = places
        hasConfiguredPlaces = true
        authorizationStatus = locationManager.authorizationStatus

        guard isAutomaticTrackingEnabled else {
            stopWorkTrackRegions()
            trackingStatus = .idle
            return
        }

        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            closeOpenVisits()
            stopWorkTrackRegions()
            trackingStatus = .unavailable("Geofence monitoring is not available on this device.")
            return
        }

        let authorizationStatus = locationManager.authorizationStatus
        guard authorizationStatus == .authorizedAlways else {
            closeOpenVisits()
            stopWorkTrackRegions()
            trackingStatus = .permissionNeeded(permissionMessage(for: authorizationStatus))
            return
        }

        let activePlaces = selectedMonitorablePlaces(from: places)
        guard !activePlaces.isEmpty else {
            closeOpenVisits()
            stopWorkTrackRegions()
            trackingStatus = .idle
            return
        }

        guard !Self.hasAmbiguousOverlap(in: activePlaces) else {
            closeOpenVisits()
            stopWorkTrackRegions()
            trackingStatus = .failed(
                "The active home and office areas overlap. Reduce a radius or move a saved area "
                    + "before enabling automation."
            )
            return
        }

        synchronizeMonitoring(for: activePlaces)
    }

    private func synchronizeMonitoring(for activePlaces: [Place]) {
        let maximumDistance = locationManager.maximumRegionMonitoringDistance
        let desiredRegions = activePlaces.compactMap { place in
            Self.makeRegion(for: place, maximumMonitoringDistance: maximumDistance)
        }
        let desiredIdentifiers = Set(desiredRegions.map(\.identifier))

        let regionsToStop = locationManager.monitoredRegions.filter {
                $0.identifier.hasPrefix(Self.regionIdentifierPrefix)
                    && !desiredIdentifiers.contains($0.identifier)
            }
        closeOpenVisits(for: Set(regionsToStop.map(\.identifier)))
        regionsToStop.forEach(locationManager.stopMonitoring(for:))

        monitoredPlaceSnapshots = Dictionary(
            uniqueKeysWithValues: activePlaces.map { place in
                (
                    Self.regionIdentifier(for: place),
                    MonitoredPlaceSnapshot(
                        placeId: place.id,
                        placeName: place.name,
                        placeType: place.type ?? .office
                    )
                )
            }
        )

        for region in desiredRegions {
            if let existingRegion = locationManager.monitoredRegions.first(
                where: { $0.identifier == region.identifier }
            ),
               Self.region(existingRegion, matches: region) {
                continue
            }

            if let existingRegion = locationManager.monitoredRegions.first(
                where: { $0.identifier == region.identifier }
            ) {
                closeOpenVisits(for: [existingRegion.identifier])
                locationManager.stopMonitoring(for: existingRegion)
            }
            locationManager.startMonitoring(for: region)
            locationManager.requestState(for: region)
        }

        trackingStatus = .monitoring(desiredRegions.count)
    }

    @discardableResult
    func setAutomaticTrackingEnabled(_ enabled: Bool, for places: [Place]) -> Bool {
        lastConfiguredPlaces = places
        authorizationStatus = locationManager.authorizationStatus

        guard enabled else {
            closeOpenVisits()
            defaults.set(false, forKey: automationPreferenceKey)
            isAutomaticTrackingEnabled = false
            stopWorkTrackRegions()
            trackingStatus = .idle
            return true
        }

        guard authorizationStatus == .authorizedAlways else {
            trackingStatus = .permissionNeeded(permissionMessage(for: authorizationStatus))
            return false
        }

        let activePlaces = selectedMonitorablePlaces(from: places)
        guard !activePlaces.isEmpty else {
            trackingStatus = .permissionNeeded("Save and enable a home or office place before turning on automation.")
            return false
        }

        guard !Self.hasAmbiguousOverlap(in: activePlaces) else {
            trackingStatus = .failed(
                "The active home and office areas overlap. Reduce a radius or move a saved area "
                    + "before enabling automation."
            )
            return false
        }

        defaults.set(true, forKey: automationPreferenceKey)
        isAutomaticTrackingEnabled = true
        refreshMonitoring(for: places)

        if case .monitoring = trackingStatus {
            return true
        }
        return false
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = locationManager.authorizationStatus
        if isAutomaticTrackingEnabled {
            refreshMonitoring(for: lastConfiguredPlaces)
        }
    }

    func reseedCurrentRegionStates() {
        guard isAutomaticTrackingEnabled, authorizationStatus == .authorizedAlways else {
            return
        }

        locationManager.monitoredRegions
            .filter { $0.identifier.hasPrefix(Self.regionIdentifierPrefix) }
            .forEach(locationManager.requestState(for:))
    }

    func requestForegroundAuthorizationForAutomation() {
        authorizationStatus = locationManager.authorizationStatus
        guard authorizationStatus == .notDetermined else {
            return
        }

        trackingStatus = .permissionNeeded(
            "First allow location while using Work Track. You can then choose background access "
                + "for automatic attendance."
        )
        locationManager.requestWhenInUseAuthorization()
    }

    func requestAlwaysAuthorizationForAutomation() {
        authorizationStatus = locationManager.authorizationStatus
        guard authorizationStatus == .authorizedWhenInUse else {
            return
        }

        trackingStatus = .permissionNeeded(
            "Choose Always in the iOS prompt so saved-place boundary events can arrive when Work Track is closed."
        )
        locationManager.requestAlwaysAuthorization()
    }

    static func makeRegion(for place: Place, maximumMonitoringDistance: CLLocationDistance) -> CLCircularRegion? {
        guard place.isActive, place.type != nil else {
            return nil
        }

        let maximumRadius = maximumMonitoringDistance > 0 ? maximumMonitoringDistance : place.radiusMeters
        let radius = min(max(place.radiusMeters, 1), maximumRadius)
        let center = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
        let region = CLCircularRegion(center: center, radius: radius, identifier: regionIdentifier(for: place))
        region.notifyOnEntry = true
        region.notifyOnExit = true
        return region
    }

    static func regionIdentifier(for place: Place) -> String {
        "\(regionIdentifierPrefix).\(place.typeRaw).\(place.id.uuidString)"
    }

    static func placeType(from regionIdentifier: String) -> PlaceType? {
        let components = regionIdentifier.split(separator: ".")
        guard components.count == 4 else {
            return nil
        }

        return PlaceType(rawValue: String(components[2]))
    }

    static func placeId(from regionIdentifier: String) -> UUID? {
        let components = regionIdentifier.split(separator: ".")
        guard components.count == 4 else {
            return nil
        }

        return UUID(uuidString: String(components[3]))
    }

    static func region(_ existing: CLRegion, matches desired: CLCircularRegion) -> Bool {
        guard let existing = existing as? CLCircularRegion else {
            return false
        }

        return abs(existing.center.latitude - desired.center.latitude) < 0.000_001
            && abs(existing.center.longitude - desired.center.longitude) < 0.000_001
            && abs(existing.radius - desired.radius) < 0.5
            && existing.notifyOnEntry == desired.notifyOnEntry
            && existing.notifyOnExit == desired.notifyOnExit
    }

    static func hasAmbiguousOverlap(in places: [Place]) -> Bool {
        let activePlaces = places.filter { $0.isActive && $0.type != nil }

        for (index, firstPlace) in activePlaces.enumerated() {
            for secondPlace in activePlaces.dropFirst(index + 1) {
                guard firstPlace.type != secondPlace.type else {
                    continue
                }

                let firstLocation = CLLocation(
                    latitude: firstPlace.latitude,
                    longitude: firstPlace.longitude
                )
                let secondLocation = CLLocation(
                    latitude: secondPlace.latitude,
                    longitude: secondPlace.longitude
                )
                if firstLocation.distance(from: secondLocation)
                    < firstPlace.radiusMeters + secondPlace.radiusMeters {
                    return true
                }
            }
        }

        return false
    }

    private func selectedMonitorablePlaces(from places: [Place]) -> [Place] {
        var selectedPlacesByType: [PlaceType: Place] = [:]

        for place in places where place.isActive {
            guard let placeType = place.type, selectedPlacesByType[placeType] == nil else {
                continue
            }
            selectedPlacesByType[placeType] = place
        }

        return PlaceType.allCases.compactMap { selectedPlacesByType[$0] }
    }

    private func stopWorkTrackRegions() {
        locationManager.monitoredRegions
            .filter { $0.identifier.hasPrefix(Self.regionIdentifierPrefix) }
            .forEach(locationManager.stopMonitoring(for:))
        monitoredPlaceSnapshots = [:]
    }

    private func closeOpenVisits(
        for regionIdentifiers: Set<String>? = nil,
        at occurredAt: Date = .now
    ) {
        guard let modelContext,
              let events = try? modelContext.fetch(FetchDescriptor<LocationEvent>()) else {
            return
        }

        let openEntries = LocationVisitResolver().openEntries(from: events).filter { entry in
            regionIdentifiers?.contains(entry.regionIdentifier) ?? true
        }
        for entry in openEntries {
            persistEvent(
                PendingRegionEvent(
                    regionIdentifier: entry.regionIdentifier,
                    kind: .exited,
                    occurredAt: occurredAt
                )
            )
        }
    }

    func recordBoundaryEvent(
        regionIdentifier: String,
        kind: LocationEventKind,
        occurredAt: Date = .now
    ) {
        guard isAutomaticTrackingEnabled else {
            return
        }

        let pendingEvent = PendingRegionEvent(
            regionIdentifier: regionIdentifier,
            kind: kind,
            occurredAt: occurredAt
        )

        guard modelContext != nil else {
            pendingRegionEvents.append(pendingEvent)
            return
        }

        persistEvent(pendingEvent)
    }

    private func persistEvent(for region: CLRegion, kind: LocationEventKind) {
        recordBoundaryEvent(regionIdentifier: region.identifier, kind: kind)
    }

    private func persistEvent(_ pendingEvent: PendingRegionEvent) {
        guard pendingEvent.regionIdentifier.hasPrefix(Self.regionIdentifierPrefix) else {
            return
        }

        guard let placeType = Self.placeType(from: pendingEvent.regionIdentifier) else {
            trackingStatus = .failed("Received a geofence event with an unknown place type.")
            return
        }

        guard let modelContext else {
            pendingRegionEvents.append(pendingEvent)
            return
        }

        do {
            let existingEvents = try modelContext.fetch(FetchDescriptor<LocationEvent>())
            let isDuplicate = existingEvents.contains { event in
                event.regionIdentifier == pendingEvent.regionIdentifier
                    && event.eventKind == pendingEvent.kind
                    && abs(event.occurredAt.timeIntervalSince(pendingEvent.occurredAt)) < 60
            }
            guard !isDuplicate else {
                return
            }
        } catch {
            trackingStatus = .failed("Location event could not be checked before saving.")
            return
        }

        let placeId = Self.placeId(from: pendingEvent.regionIdentifier)
        let snapshot = monitoredPlaceSnapshots[pendingEvent.regionIdentifier]
        let event = LocationEvent(
            placeId: placeId,
            placeName: snapshot?.placeName ?? placeType.displayName,
            placeType: snapshot?.placeType ?? placeType,
            eventKind: pendingEvent.kind,
            regionIdentifier: pendingEvent.regionIdentifier,
            occurredAt: pendingEvent.occurredAt
        )
        modelContext.insert(event)

        do {
            try AutomatedAttendanceEventProcessor().recalculateAttendance(
                affectedBy: event,
                in: modelContext
            )
            try modelContext.save()
        } catch {
            modelContext.rollback()
            trackingStatus = .failed("Location event could not be saved.")
        }
    }

    private func flushPendingRegionEvents() {
        guard modelContext != nil, !pendingRegionEvents.isEmpty else {
            return
        }

        let queuedEvents = pendingRegionEvents
        pendingRegionEvents.removeAll()
        queuedEvents.forEach(persistEvent)
    }

    private func permissionMessage(for authorizationStatus: CLAuthorizationStatus) -> String {
        switch authorizationStatus {
        case .notDetermined:
            "Allow location access before automatic home and office tracking can start."
        case .restricted:
            "Location access is restricted on this device. Manual attendance still works."
        case .denied:
            "Location access is off for Work Track. Manual attendance still works."
        case .authorizedWhenInUse:
            "Background location access is needed for geofence events when the app is not open. "
                + "Manual attendance still works."
        case .authorizedAlways:
            "Location tracking is ready."
        @unknown default:
            "Work Track cannot identify the current location permission state. Manual attendance still works."
        }
    }
}

extension LocationTrackingService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            if isAutomaticTrackingEnabled, hasConfiguredPlaces {
                refreshMonitoring(for: lastConfiguredPlaces)
            } else if authorizationStatus == .authorizedAlways {
                trackingStatus = .idle
            } else {
                trackingStatus = .permissionNeeded(permissionMessage(for: authorizationStatus))
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        Task { @MainActor in
            persistEvent(for: region, kind: .entered)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        Task { @MainActor in
            persistEvent(for: region, kind: .exited)
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didDetermineState state: CLRegionState,
        for region: CLRegion
    ) {
        guard state == .inside else {
            return
        }

        Task { @MainActor in
            persistEvent(for: region, kind: .entered)
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        monitoringDidFailFor region: CLRegion?,
        withError error: Error
    ) {
        Task { @MainActor in
            if let region {
                trackingStatus = .failed("Monitoring failed for \(region.identifier). Manual attendance still works.")
            } else {
                trackingStatus = .failed("Location monitoring failed. Manual attendance still works.")
            }
        }
    }
}

private struct MonitoredPlaceSnapshot {
    let placeId: UUID
    let placeName: String
    let placeType: PlaceType
}

private struct PendingRegionEvent {
    let regionIdentifier: String
    let kind: LocationEventKind
    let occurredAt: Date
}
