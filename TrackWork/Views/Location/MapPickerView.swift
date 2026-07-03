import MapKit
import SwiftUI

struct MapPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let placeType: PlaceType
    let radiusMeters: Double
    let onSelection: (CLLocationCoordinate2D) -> Void

    @State private var selectedCoordinate: CLLocationCoordinate2D
    @State private var cameraPosition: MapCameraPosition

    init(
        placeType: PlaceType,
        initialCoordinate: CLLocationCoordinate2D?,
        radiusMeters: Double,
        onSelection: @escaping (CLLocationCoordinate2D) -> Void
    ) {
        let coordinate = initialCoordinate ?? Self.defaultCoordinate
        self.placeType = placeType
        self.radiusMeters = radiusMeters
        self.onSelection = onSelection
        _selectedCoordinate = State(initialValue: coordinate)
        _cameraPosition = State(initialValue: .region(Self.region(centeredOn: coordinate)))
    }

    var body: some View {
        VStack(spacing: 0) {
            MapReader { proxy in
                Map(position: $cameraPosition, interactionModes: .all) {
                    MapCircle(center: selectedCoordinate, radius: radiusMeters)
                        .foregroundStyle(Color.ds.accentPrimary.opacity(0.14))

                    MapCircle(center: selectedCoordinate, radius: radiusMeters)
                        .stroke(Color.ds.accentPrimary, lineWidth: 2)

                    Marker(placeType.displayName, coordinate: selectedCoordinate)
                        .tint(Color.ds.accentPrimary)
                }
                .mapControls {
                    MapCompass()
                    MapScaleView()
                }
                .onTapGesture(coordinateSpace: .local) { point in
                    guard let coordinate = proxy.convert(point, from: .local) else {
                        return
                    }
                    updateSelectedCoordinate(coordinate, recenter: false)
                }
                .accessibilityIdentifier("mapPicker.map")
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Selected Coordinate")
                            .font(AppTypography.caption)
                            .foregroundStyle(Color.ds.textSecondary)

                        Text(Self.formattedCoordinatePair(selectedCoordinate))
                            .font(AppTypography.body)
                            .foregroundStyle(Color.ds.textPrimary)
                            .monospacedDigit()
                    }

                    Spacer()

                    Button {
                        useMapCenter()
                    } label: {
                        Label("Use Center", systemImage: "scope")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("mapPicker.useCenter")
                }

                Text("Tap the map to move the pin, or pan and zoom the map then use the center point. This does not request current location access.")
                    .font(AppTypography.caption)
                    .foregroundStyle(Color.ds.textSecondary)
            }
            .padding()
            .background(Color.ds.surfacePrimary)
        }
        .navigationTitle("Choose \(placeType.displayName)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    onSelection(selectedCoordinate)
                    dismiss()
                }
                .accessibilityIdentifier("mapPicker.done")
            }
        }
    }

    private func useMapCenter() {
        guard let center = cameraPosition.region?.center else {
            return
        }

        updateSelectedCoordinate(center, recenter: false)
    }

    private func updateSelectedCoordinate(_ coordinate: CLLocationCoordinate2D, recenter: Bool) {
        let clampedCoordinate = CLLocationCoordinate2D(
            latitude: min(max(coordinate.latitude, -90), 90),
            longitude: min(max(coordinate.longitude, -180), 180)
        )

        selectedCoordinate = clampedCoordinate

        if recenter {
            cameraPosition = .region(Self.region(centeredOn: clampedCoordinate))
        }
    }

    private static func region(centeredOn coordinate: CLLocationCoordinate2D) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 1600,
            longitudinalMeters: 1600
        )
    }

    private static func formattedCoordinatePair(_ coordinate: CLLocationCoordinate2D) -> String {
        "\(formattedCoordinate(coordinate.latitude)), \(formattedCoordinate(coordinate.longitude))"
    }

    private static func formattedCoordinate(_ coordinate: Double) -> String {
        coordinateFormatter.string(from: NSNumber(value: coordinate)) ?? ""
    }

    private static let coordinateFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 6
        formatter.usesGroupingSeparator = false
        return formatter
    }()

    private static let defaultCoordinate = CLLocationCoordinate2D(
        latitude: -37.8136,
        longitude: 144.9631
    )
}

#Preview {
    NavigationStack {
        MapPickerView(
            placeType: .office,
            initialCoordinate: CLLocationCoordinate2D(latitude: -37.8136, longitude: 144.9631),
            radiusMeters: 150
        ) { _ in }
    }
}
