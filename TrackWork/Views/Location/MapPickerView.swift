import CoreLocation
import MapKit
import SwiftUI

struct MapPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let placeType: PlaceType
    let radiusMeters: Double
    let onSelection: (PlaceSelection) -> Void

    @State private var selectedCoordinate: CLLocationCoordinate2D
    @State private var selectedAddress: String
    @State private var cameraPosition: MapCameraPosition
    @State private var selectionRevision = 0
    @State private var isResolvingAddress = false

    private let lookupService = PlaceLookupService()

    init(
        placeType: PlaceType,
        initialSelection: PlaceSelection?,
        radiusMeters: Double,
        onSelection: @escaping (PlaceSelection) -> Void
    ) {
        let coordinate = initialSelection?.coordinate ?? Self.defaultCoordinate
        self.placeType = placeType
        self.radiusMeters = radiusMeters
        self.onSelection = onSelection
        _selectedCoordinate = State(initialValue: coordinate)
        _selectedAddress = State(initialValue: initialSelection?.formattedAddress ?? "Pinned location")
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
                    updateSelectedCoordinate(coordinate)
                }
                .accessibilityIdentifier("mapPicker.map")
            }

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.ds.accentPrimary)

                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text("Selected place")
                            .font(AppTypography.captionStrong)
                            .foregroundStyle(Color.ds.textSecondary)

                        if isResolvingAddress {
                            Text("Finding address…")
                                .font(AppTypography.body)
                                .foregroundStyle(Color.ds.textSecondary)
                        } else {
                            Text(selectedAddress)
                                .font(AppTypography.body)
                                .foregroundStyle(Color.ds.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer(minLength: AppSpacing.sm)

                    Button {
                        useMapCenter()
                    } label: {
                        Label("Use Center", systemImage: "scope")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("mapPicker.useCenter")
                }

                Text("Tap the map or use its center.")
                    .font(AppTypography.caption)
                    .foregroundStyle(Color.ds.textSecondary)
            }
            .padding(AppSpacing.md)
            .background(Color.ds.surfacePrimary)
        }
        .navigationTitle("Choose \(placeType.displayName)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    onSelection(
                        PlaceSelection(
                            coordinate: selectedCoordinate,
                            formattedAddress: selectedAddress
                        )
                    )
                    dismiss()
                }
                .accessibilityIdentifier("mapPicker.done")
            }
        }
        .task(id: selectionRevision) {
            do {
                try await Task.sleep(for: .milliseconds(450))
                await resolveSelectedAddress()
            } catch is CancellationError {
                return
            } catch {
                return
            }
        }
    }

    private func useMapCenter() {
        guard let center = cameraPosition.region?.center else {
            return
        }

        updateSelectedCoordinate(center)
    }

    private func updateSelectedCoordinate(_ coordinate: CLLocationCoordinate2D) {
        selectedCoordinate = CLLocationCoordinate2D(
            latitude: min(max(coordinate.latitude, -90), 90),
            longitude: min(max(coordinate.longitude, -180), 180)
        )
        selectedAddress = "Pinned location"
        selectionRevision += 1
    }

    private func resolveSelectedAddress() async {
        isResolvingAddress = true
        let location = CLLocation(
            latitude: selectedCoordinate.latitude,
            longitude: selectedCoordinate.longitude
        )
        let resolvedSelection = await lookupService.selection(for: location)
        selectedAddress = resolvedSelection.formattedAddress
        isResolvingAddress = false
    }

    private static func region(centeredOn coordinate: CLLocationCoordinate2D) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 1600,
            longitudinalMeters: 1600
        )
    }

    private static let defaultCoordinate = CLLocationCoordinate2D(
        latitude: -37.8136,
        longitude: 144.9631
    )
}

#Preview {
    NavigationStack {
        MapPickerView(
            placeType: .office,
            initialSelection: PlaceSelection(
                latitude: -37.8136,
                longitude: 144.9631,
                formattedAddress: "Melbourne VIC, Australia"
            ),
            radiusMeters: 150
        ) { _ in }
    }
}
