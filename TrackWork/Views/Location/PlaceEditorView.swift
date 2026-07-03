import SwiftData
import SwiftUI

struct PlaceEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Place.typeRaw) private var places: [Place]

    let placeType: PlaceType
    let place: Place?

    @State private var name: String
    @State private var latitudeText: String
    @State private var longitudeText: String
    @State private var radiusMeters: Double
    @State private var saveError: String?

    private let radiusOptions = [50.0, 100.0, 150.0, 200.0, 300.0, 500.0]

    init(placeType: PlaceType, place: Place?) {
        self.placeType = placeType
        self.place = place
        _name = State(initialValue: place?.name ?? placeType.defaultName)
        _latitudeText = State(initialValue: place.map { Self.formattedCoordinate($0.latitude) } ?? "")
        _longitudeText = State(initialValue: place.map { Self.formattedCoordinate($0.longitude) } ?? "")
        _radiusMeters = State(initialValue: place?.radiusMeters ?? 150)
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                    .textInputAutocapitalization(.words)

                TextField("Latitude", text: $latitudeText)
                    .keyboardType(.numbersAndPunctuation)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("placeEditor.latitude")

                TextField("Longitude", text: $longitudeText)
                    .keyboardType(.numbersAndPunctuation)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("placeEditor.longitude")
            } header: {
                Text("Coordinates")
            } footer: {
                Text("Enter decimal coordinates manually for now. This does not request location access or start tracking.")
            }

            Section {
                Picker("Radius", selection: $radiusMeters) {
                    ForEach(radiusOptions, id: \.self) { radius in
                        Text("\(radius.formatted(.number.precision(.fractionLength(0)))) m")
                            .tag(radius)
                    }
                }
            } header: {
                Text("Detection Radius")
            } footer: {
                Text("150 metres is the default. Geofencing will be added in a later milestone.")
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
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    savePlace()
                }
            }
        }
    }

    private func savePlace() {
        saveError = nil

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            saveError = "Enter a name for this place."
            return
        }

        guard let latitude = coordinate(from: latitudeText), (-90...90).contains(latitude) else {
            saveError = "Enter a latitude from -90 to 90."
            return
        }

        guard let longitude = coordinate(from: longitudeText), (-180...180).contains(longitude) else {
            saveError = "Enter a longitude from -180 to 180."
            return
        }

        let editablePlace = place ?? places.first { $0.type == placeType }

        if let editablePlace {
            editablePlace.name = trimmedName
            editablePlace.typeRaw = placeType.rawValue
            editablePlace.latitude = latitude
            editablePlace.longitude = longitude
            editablePlace.radiusMeters = radiusMeters
            editablePlace.isActive = true
            editablePlace.updatedAt = .now
        } else {
            let newPlace = Place(
                name: trimmedName,
                type: placeType,
                latitude: latitude,
                longitude: longitude,
                radiusMeters: radiusMeters
            )
            modelContext.insert(newPlace)
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            saveError = "Place could not be saved. Try again."
        }
    }

    private func coordinate(from text: String) -> Double? {
        Double(text.trimmingCharacters(in: .whitespacesAndNewlines))
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
}

#Preview("Home") {
    NavigationStack {
        PlaceEditorView(placeType: .home, place: nil)
    }
    .modelContainer(PreviewData.modelContainer())
}
