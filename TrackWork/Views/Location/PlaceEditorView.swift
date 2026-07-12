import MapKit
import SwiftData
import SwiftUI
import UIKit

struct PlaceEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Query(sort: \Place.typeRaw) private var places: [Place]

    let placeType: PlaceType
    let place: Place?

    @State private var name: String
    @State private var selection: PlaceSelection?
    @State private var radiusMeters: Double
    @State private var isShowingAddressSearch = false
    @State private var isShowingMapPicker = false
    @State private var isShowingCurrentLocationExplanation = false
    @State private var isResolvingCurrentLocation = false
    @State private var selectionNotice: String?
    @State private var saveError: String?
    @State private var locationService = LocationAuthorizationService()

    private let lookupService = PlaceLookupService()
    private let radiusOptions = [50.0, 100.0, 150.0, 200.0, 300.0, 500.0]

    @MainActor
    init(placeType: PlaceType, place: Place?) {
        self.placeType = placeType
        self.place = place
        _name = State(initialValue: place?.name ?? placeType.defaultName)
        _selection = State(initialValue: place.map(PlaceSelection.init(place:)))
        _radiusMeters = State(initialValue: place?.radiusMeters ?? 150)
    }

    var body: some View {
        Form {
            Section("Details") {
                TextField("Name", text: $name)
                    .textInputAutocapitalization(.words)
                    .accessibilityIdentifier("placeEditor.name")
            }

            Section {
                if let selection {
                    selectedPlaceRow(selection)
                } else {
                    Label {
                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            Text("No place selected")
                                .foregroundStyle(Color.ds.textPrimary)
                            Text("Search for an address or use your current location.")
                                .font(AppTypography.caption)
                                .foregroundStyle(Color.ds.textSecondary)
                        }
                    } icon: {
                        Image(systemName: "mappin.slash")
                            .foregroundStyle(Color.ds.textTertiary)
                    }
                }

                Button {
                    isShowingAddressSearch = true
                } label: {
                    Label("Search Address or Place", systemImage: "magnifyingglass")
                }
                .accessibilityIdentifier("placeEditor.searchAddress")

                Button {
                    isShowingCurrentLocationExplanation = true
                } label: {
                    if locationService.isRequestingLocation || isResolvingCurrentLocation {
                        HStack(spacing: AppSpacing.sm) {
                            ProgressView()
                            Text("Finding Current Location…")
                        }
                    } else {
                        Label("Use Current Location", systemImage: "location.fill")
                    }
                }
                .disabled(locationService.isRequestingLocation || isResolvingCurrentLocation)
                .accessibilityIdentifier("placeEditor.useCurrentLocation")

                Button {
                    isShowingMapPicker = true
                } label: {
                    Label(selection == nil ? "Choose on Map" : "Adjust on Map", systemImage: "map")
                }
                .accessibilityIdentifier("placeEditor.chooseOnMap")
            } header: {
                Text("Location")
            } footer: {
                Text(
                    "Address search is provided by Apple Maps. Current Location requests one location fix only "
                        + "after you choose it; Work Track does not start background or continuous tracking."
                )
            }

            Section {
                Picker("Area around place", selection: $radiusMeters) {
                    ForEach(radiusOptions, id: \.self) { radius in
                        Text("\(radius.formatted(.number.precision(.fractionLength(0)))) m")
                            .tag(radius)
                    }
                }
            } header: {
                Text("Place Area")
            } footer: {
                Text("Choose how close you need to be for this place. 150 metres works well for most homes and offices.")
            }

            if let selectionNotice {
                Section {
                    Label(selectionNotice, systemImage: "location.circle")
                        .font(AppTypography.callout)
                        .foregroundStyle(Color.ds.textSecondary)
                }
            }

            if let locationError = locationService.errorMessage {
                Section {
                    Label(locationError, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(Color.ds.critical)
                        .accessibilityIdentifier("placeEditor.locationError")

                    if locationService.isPermissionDenied {
                        Button("Open iOS Settings") {
                            guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
                                return
                            }
                            openURL(settingsURL)
                        }
                    }
                }
            }

            if let saveError {
                Section {
                    Text(saveError)
                        .foregroundStyle(Color.ds.critical)
                }
            }
        }
        .navigationTitle(placeType.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    savePlace()
                }
                .disabled(!canSave)
                .accessibilityIdentifier("placeEditor.save")
            }
        }
        .sheet(isPresented: $isShowingAddressSearch) {
            AddressSearchView { selection in
                applySelection(selection)
            }
        }
        .sheet(isPresented: $isShowingMapPicker) {
            NavigationStack {
                MapPickerView(
                    placeType: placeType,
                    initialSelection: selection,
                    radiusMeters: radiusMeters
                ) { selection in
                    applySelection(selection)
                }
            }
        }
        .alert("Use your current location?", isPresented: $isShowingCurrentLocationExplanation) {
            Button("Cancel", role: .cancel) {}
            Button("Use Current Location") {
                selectionNotice = nil
                locationService.requestCurrentLocation()
            }
        } message: {
            Text(
                "Work Track will ask iOS for one location fix to place this pin. It will not request Always access "
                    + "or start background or continuous tracking."
            )
        }
        .onChange(of: locationService.locationUpdateID) {
            guard let location = locationService.currentLocation else {
                return
            }

            Task { await applyCurrentLocation(location) }
        }
    }

    private func selectedPlaceRow(_ selection: PlaceSelection) -> some View {
        Label {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("Selected place")
                    .font(AppTypography.captionStrong)
                    .foregroundStyle(Color.ds.textSecondary)

                Text(selection.formattedAddress)
                    .font(AppTypography.body)
                    .foregroundStyle(Color.ds.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } icon: {
            Image(systemName: "mappin.circle.fill")
                .font(.title2)
                .foregroundStyle(Color.ds.accentPrimary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("placeEditor.selectedPlace")
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selection != nil
    }

    private func savePlace() {
        saveError = nil

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            saveError = "Enter a name for this place."
            return
        }

        guard let selection else {
            saveError = "Search for an address, use your current location, or choose a point on the map."
            return
        }

        let editablePlace = place ?? places.first { $0.type == placeType }

        if let editablePlace {
            editablePlace.name = trimmedName
            editablePlace.typeRaw = placeType.rawValue
            editablePlace.latitude = selection.latitude
            editablePlace.longitude = selection.longitude
            editablePlace.formattedAddress = selection.formattedAddress
            editablePlace.radiusMeters = radiusMeters
            editablePlace.isActive = true
            editablePlace.updatedAt = .now
        } else {
            modelContext.insert(
                Place(
                    name: trimmedName,
                    type: placeType,
                    latitude: selection.latitude,
                    longitude: selection.longitude,
                    formattedAddress: selection.formattedAddress,
                    radiusMeters: radiusMeters
                )
            )
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            saveError = "Place could not be saved. Try again."
        }
    }

    private func applySelection(_ selection: PlaceSelection) {
        self.selection = selection
        selectionNotice = nil
        saveError = nil
    }

    private func applyCurrentLocation(_ location: CLLocation) async {
        isResolvingCurrentLocation = true
        let selection = await lookupService.selection(for: location, fallback: "Current location")
        applySelection(selection)

        if location.horizontalAccuracy > 200 {
            selectionNotice = "This is an approximate location. Use Adjust on Map if the pin needs fine-tuning."
        }

        isResolvingCurrentLocation = false
    }
}

#Preview("Home") {
    NavigationStack {
        PlaceEditorView(placeType: .home, place: nil)
    }
    .modelContainer(PreviewData.modelContainer())
}
