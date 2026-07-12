import CoreLocation
import MapKit

struct PlaceSearchResult: Identifiable, Equatable, Sendable {
    let title: String
    let selection: PlaceSelection

    var id: String {
        "\(selection.latitude),\(selection.longitude),\(title)"
    }
}

@MainActor
struct PlaceLookupService {
    enum LookupError: LocalizedError {
        case invalidQuery
        case noResults

        var errorDescription: String? {
            switch self {
            case .invalidQuery:
                "Enter an address or place to search."
            case .noResults:
                "No matching places were found. Try including a suburb or postcode."
            }
        }
    }

    func search(for query: String) async throws -> [PlaceSearchResult] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            throw LookupError.invalidQuery
        }

        let request = MKLocalSearch.Request(naturalLanguageQuery: trimmedQuery)
        request.resultTypes = [.address, .pointOfInterest]
        let response = try await MKLocalSearch(request: request).start()
        let results = response.mapItems.prefix(12).map(Self.searchResult(from:))

        guard !results.isEmpty else {
            throw LookupError.noResults
        }

        return results
    }

    func selection(for location: CLLocation, fallback: String = "Pinned location") async -> PlaceSelection {
        guard let request = MKReverseGeocodingRequest(location: location) else {
            return PlaceSelection(coordinate: location.coordinate, formattedAddress: fallback)
        }

        do {
            guard let mapItem = try await request.mapItems.first else {
                return PlaceSelection(coordinate: location.coordinate, formattedAddress: fallback)
            }
            return Self.placeSelection(from: mapItem, fallback: fallback)
        } catch {
            return PlaceSelection(coordinate: location.coordinate, formattedAddress: fallback)
        }
    }

    static func displayAddress(for mapItem: MKMapItem, fallback: String) -> String {
        mapItem.addressRepresentations?.fullAddress(includingRegion: true, singleLine: true)
            ?? mapItem.address?.fullAddress
            ?? mapItem.name
            ?? fallback
    }

    private static func searchResult(from mapItem: MKMapItem) -> PlaceSearchResult {
        let address = displayAddress(for: mapItem, fallback: "Selected place")
        return PlaceSearchResult(
            title: mapItem.name ?? address,
            selection: PlaceSelection(
                coordinate: mapItem.location.coordinate,
                formattedAddress: address
            )
        )
    }

    private static func placeSelection(from mapItem: MKMapItem, fallback: String) -> PlaceSelection {
        PlaceSelection(
            coordinate: mapItem.location.coordinate,
            formattedAddress: displayAddress(for: mapItem, fallback: fallback)
        )
    }
}
