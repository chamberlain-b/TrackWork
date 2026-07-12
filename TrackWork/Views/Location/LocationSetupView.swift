import SwiftData
import SwiftUI

struct LocationSetupView: View {
    @Environment(LocationTrackingService.self) private var locationTrackingService
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
                Label {
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text("Choose places without technical coordinates")
                            .font(AppTypography.headline)
                            .foregroundStyle(Color.ds.textPrimary)

                        Text("Search an address, use your current location once, or adjust the pin on a map.")
                            .font(AppTypography.caption)
                            .foregroundStyle(Color.ds.textSecondary)
                    }
                } icon: {
                    Image(systemName: "map.fill")
                        .foregroundStyle(Color.ds.accentPrimary)
                }
            } header: {
                Text("Place Selection")
            } footer: {
                Text(
                    "Saving a place does not enable automatic attendance detection, background location, or "
                        + "continuous tracking. Manual attendance remains available."
                )
            }

            Section {
                placeRow(for: .home, place: homePlace)
                placeRow(for: .office, place: officePlace)
            } header: {
                Text("Places")
            } footer: {
                Text("Home and office locations are stored on this device and excluded from standard reports.")
            }
        }
        .navigationTitle("Location Setup")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            locationTrackingService.refreshMonitoring(for: places)
        }
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
        .accessibilityLabel("\(placeType.displayName): \(summary(for: place))")
        .accessibilityIdentifier("locationSetup.\(placeType.rawValue)")
    }

    private func place(for placeType: PlaceType) -> Place? {
        places.first { $0.type == placeType }
    }

    private func summary(for place: Place?) -> String {
        guard let place else {
            return "Not configured"
        }

        let radius = place.radiusMeters.formatted(.number.precision(.fractionLength(0)))
        return "\(place.displayAddress) · \(radius) m area"
    }

}

#Preview {
    NavigationStack {
        LocationSetupView()
    }
    .modelContainer(PreviewData.modelContainer())
    .environment(LocationTrackingService())
}
