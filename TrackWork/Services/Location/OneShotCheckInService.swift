import CoreLocation
import Foundation

struct OneShotCheckInResult: Equatable {
    enum Outcome: Equatable {
        case matched
        case noActivePlaces
        case outsideSavedPlaces
        case ambiguousMatches
        case invalidLocation
    }

    let outcome: Outcome
    let classification: AttendanceClassification
    let matchedPlaceID: UUID?
    let matchedPlaceName: String?

    var canApplyToAttendance: Bool {
        outcome == .matched && (classification == .office || classification == .home)
    }
}

enum OneShotCheckInApplicationResult: Equatable {
    case appliedDetectedAndFinal
    case appliedDetectedPreservingManualFinal
    case appliedDetectedPreservingExcludedFinal
    case notApplied
}

struct OneShotCheckInService {
    func classify(_ location: CLLocation, against places: [Place]) -> OneShotCheckInResult {
        guard CLLocationCoordinate2DIsValid(location.coordinate) else {
            return unresolvedResult(.invalidLocation)
        }

        let activePlaces = places.compactMap { place in
            ActivePlaceSnapshot(place: place)
        }
        guard !activePlaces.isEmpty else {
            return unresolvedResult(.noActivePlaces)
        }

        let matches = activePlaces.compactMap { place -> PlaceMatch? in
            let savedLocation = CLLocation(latitude: place.latitude, longitude: place.longitude)
            let distance = location.distance(from: savedLocation)
            guard distance.isFinite, distance <= place.radiusMeters else {
                return nil
            }

            return PlaceMatch(place: place, distanceMeters: distance)
        }

        guard !matches.isEmpty else {
            return unresolvedResult(.outsideSavedPlaces)
        }

        let matchedTypes = Set(matches.map(\.place.type))
        guard matchedTypes.count == 1 else {
            // Overlapping home and office radii are ambiguous; do not guess or persist the raw coordinate.
            return unresolvedResult(.ambiguousMatches)
        }

        let nearestMatch = matches.min { lhs, rhs in
            if lhs.distanceMeters == rhs.distanceMeters {
                return lhs.place.id.uuidString < rhs.place.id.uuidString
            }
            return lhs.distanceMeters < rhs.distanceMeters
        }

        guard let nearestMatch else {
            return unresolvedResult(.outsideSavedPlaces)
        }

        let classification: AttendanceClassification = switch nearestMatch.place.type {
        case .office:
            .office
        case .home:
            .home
        }

        // The result contains only a derived status and saved-place identity, never the sampled GPS coordinate.
        return OneShotCheckInResult(
            outcome: .matched,
            classification: classification,
            matchedPlaceID: nearestMatch.place.id,
            matchedPlaceName: nearestMatch.place.name
        )
    }

    @discardableResult
    func apply(
        _ result: OneShotCheckInResult,
        to attendanceDay: AttendanceDay,
        updatedAt: Date = .now
    ) -> OneShotCheckInApplicationResult {
        guard result.canApplyToAttendance else {
            return .notApplied
        }

        attendanceDay.detectedClassificationRaw = result.classification.rawValue
        attendanceDay.updatedAt = updatedAt

        // Manual decisions remain authoritative even when a newer foreground location sample is available.
        if attendanceDay.manualClassification != nil {
            return .appliedDetectedPreservingManualFinal
        }

        if Self.isExcludedClassification(attendanceDay.finalClassification) {
            return .appliedDetectedPreservingExcludedFinal
        }

        attendanceDay.finalClassificationRaw = result.classification.rawValue
        attendanceDay.complianceTreatmentRaw = ComplianceTreatmentResolver.resolve(
            classification: result.classification,
            officeMinutes: attendanceDay.officeMinutes,
            minimumOfficeMinutes: 0
        ).rawValue
        return .appliedDetectedAndFinal
    }

    private func unresolvedResult(_ outcome: OneShotCheckInResult.Outcome) -> OneShotCheckInResult {
        OneShotCheckInResult(
            outcome: outcome,
            classification: .unknown,
            matchedPlaceID: nil,
            matchedPlaceName: nil
        )
    }

    private static func isExcludedClassification(_ classification: AttendanceClassification?) -> Bool {
        switch classification {
        case .annualLeave, .sickLeave, .publicHoliday, .weekend, .nonWorkingDay:
            true
        case .office, .home, .mixed, .unknown, nil:
            false
        }
    }
}

private struct ActivePlaceSnapshot {
    let id: UUID
    let name: String
    let type: PlaceType
    let latitude: Double
    let longitude: Double
    let radiusMeters: CLLocationDistance

    @MainActor
    init?(place: Place) {
        let coordinate = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
        guard place.isActive,
              let type = place.type,
              CLLocationCoordinate2DIsValid(coordinate),
              place.radiusMeters.isFinite,
              place.radiusMeters > 0 else {
            return nil
        }

        self.id = place.id
        self.name = place.name
        self.type = type
        self.latitude = place.latitude
        self.longitude = place.longitude
        self.radiusMeters = place.radiusMeters
    }
}

private struct PlaceMatch {
    let place: ActivePlaceSnapshot
    let distanceMeters: CLLocationDistance
}
