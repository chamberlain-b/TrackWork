import CoreLocation

struct PlaceSelection: Equatable, Sendable {
    let latitude: Double
    let longitude: Double
    let formattedAddress: String

    init(latitude: Double, longitude: Double, formattedAddress: String) {
        self.latitude = latitude
        self.longitude = longitude
        self.formattedAddress = formattedAddress
    }

    init(coordinate: CLLocationCoordinate2D, formattedAddress: String) {
        self.init(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            formattedAddress: formattedAddress
        )
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

extension PlaceSelection {
    init(place: Place) {
        self.init(
            latitude: place.latitude,
            longitude: place.longitude,
            formattedAddress: place.displayAddress
        )
    }
}
