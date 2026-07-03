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

    static let regionIdentifierPrefix = "worktrack.place"

    private let locationManager: CLLocationManager
    private var modelContext: ModelContext?
    private var monitoredPlaceSnapshots: [String: MonitoredPlaceSnapshot] = [:]

    private(set) var trackingStatus: TrackingStatus = .idle

    init(locationManager: CLLocationManager = CLLocationManager()) {
        self.locationManager = locationManager
        super.init()
        self.locationManager.delegate = self
    }

    var statusDescription: String {
        switch trackingStatus {
        case .idle:
            "Tracking is not active yet."
        case .unavailable(let message), .permissionNeeded(let message), .failed(let message):
            message
        case .monitoring(let count):
            "Monitoring \(count) saved place\(count == 1 ? "" : "s")."
        }
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func refreshMonitoring(for places: [Place]) {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            stopWorkTrackRegions()
            trackingStatus = .unavailable("Geofence monitoring is not available on this device.")
            return
        }

        let authorizationStatus = locationManager.authorizationStatus
        guard authorizationStatus == .authorizedAlways else {
            stopWorkTrackRegions()
            trackingStatus = .permissionNeeded(permissionMessage(for: authorizationStatus))
            return
        }

        let activePlaces = selectedMonitorablePlaces(from: places)
        guard !activePlaces.isEmpty else {
            stopWorkTrackRegions()
            trackingStatus = .idle
            return
        }

        let maximumDistance = locationManager.maximumRegionMonitoringDistance
        let desiredRegions = activePlaces.compactMap { place in
            Self.makeRegion(for: place, maximumMonitoringDistance: maximumDistance)
        }
        let desiredIdentifiers = Set(desiredRegions.map(\.identifier))

        locationManager.monitoredRegions
            .filter { $0.identifier.hasPrefix(Self.regionIdentifierPrefix) && !desiredIdentifiers.contains($0.identifier) }
            .forEach(locationManager.stopMonitoring(for:))

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
            if let existingRegion = locationManager.monitoredRegions.first(where: { $0.identifier == region.identifier }) {
                locationManager.stopMonitoring(for: existingRegion)
            }
            locationManager.startMonitoring(for: region)
        }

        trackingStatus = .monitoring(desiredRegions.count)
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

    private func persistEvent(for region: CLRegion, kind: LocationEventKind) {
        guard region.identifier.hasPrefix(Self.regionIdentifierPrefix) else {
            return
        }

        guard let placeType = Self.placeType(from: region.identifier) else {
            trackingStatus = .failed("Received a geofence event with an unknown place type.")
            return
        }

        let placeId = Self.placeId(from: region.identifier)
        let snapshot = monitoredPlaceSnapshots[region.identifier]
        let event = LocationEvent(
            placeId: placeId,
            placeName: snapshot?.placeName ?? placeType.displayName,
            placeType: snapshot?.placeType ?? placeType,
            eventKind: kind,
            regionIdentifier: region.identifier
        )

        guard let modelContext else {
            trackingStatus = .failed("Location event could not be saved because storage is not ready.")
            return
        }

        modelContext.insert(event)

        do {
            try recalculateAttendance(for: event, in: modelContext)
            try modelContext.save()
        } catch {
            trackingStatus = .failed("Location event could not be saved.")
        }
    }

    private func recalculateAttendance(for event: LocationEvent, in modelContext: ModelContext) throws {
        let calendar = Calendar.current
        let affectedDate = calendar.startOfDay(for: event.occurredAt)
        var attendanceDays = try modelContext.fetch(FetchDescriptor<AttendanceDay>())

        if !attendanceDays.contains(where: { calendar.startOfDay(for: $0.date) == affectedDate }) {
            let attendanceDay = AttendanceDay(date: affectedDate)
            modelContext.insert(attendanceDay)
            attendanceDays.append(attendanceDay)
        }

        let locationEvents = try modelContext.fetch(FetchDescriptor<LocationEvent>())
        let leaveRecords = try modelContext.fetch(FetchDescriptor<LeaveRecord>())
        let publicHolidays = try modelContext.fetch(FetchDescriptor<PublicHoliday>())
        let rule = try modelContext.fetch(FetchDescriptor<ComplianceRule>()).first
        let inferenceService = AttendanceInferenceService(
            calendar: calendar,
            minimumOfficeMinutes: rule?.minimumOfficeMinutes ?? 180
        )

        inferenceService.recalculateAttendanceDays(
            attendanceDays,
            affectedDates: [affectedDate],
            events: locationEvents,
            leaveRecords: leaveRecords,
            publicHolidays: publicHolidays,
            selectedISOWeekdays: Set(rule?.selectedISOWeekdays ?? [1, 2, 3, 4, 5])
        )
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
            "Background location access is needed for geofence events when the app is not open. Manual attendance still works."
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
            trackingStatus = .permissionNeeded(permissionMessage(for: manager.authorizationStatus))
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

    nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
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
