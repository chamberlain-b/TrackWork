import SwiftData
import SwiftUI

struct LocationSetupView: View {
    @Query(sort: \Place.typeRaw) private var places: [Place]

    private var homePlace: Place? {
        place(for: .home)
    }

    private var officePlace: Place? {
        place(for: .office)
    }

    var body: some View {
        List {
            Section {
                placeRow(for: .home, place: homePlace)
                placeRow(for: .office, place: officePlace)
            } header: {
                Text("Places")
            } footer: {
                Text("These saved places will be used by a later location milestone. Work Track does not request location permission or start tracking from this setup screen.")
            }
        }
        .navigationTitle("Location Setup")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func placeRow(for placeType: PlaceType, place: Place?) -> some View {
        NavigationLink {
            PlaceEditorView(placeType: placeType, place: place)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: placeType.systemImageName)
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(place == nil ? Color.ds.textTertiary : Color.ds.success)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.xs, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(placeType.displayName)
                        .font(AppTypography.headline)
                        .foregroundStyle(Color.ds.textPrimary)

                    Text(summary(for: place))
                        .font(AppTypography.caption)
                        .foregroundStyle(Color.ds.textSecondary)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 4)
        }
        .accessibilityIdentifier("locationSetup.\(placeType.rawValue)")
    }

    private func place(for placeType: PlaceType) -> Place? {
        places.first { $0.type == placeType }
    }

    private func summary(for place: Place?) -> String {
        guard let place else {
            return "Not set"
        }

        return "\(place.latitude.formatted(.number.precision(.fractionLength(4)))), \(place.longitude.formatted(.number.precision(.fractionLength(4)))) - \(place.radiusMeters.formatted(.number.precision(.fractionLength(0)))) m"
    }
}

#Preview {
    NavigationStack {
        LocationSetupView()
    }
    .modelContainer(PreviewData.modelContainer())
}
