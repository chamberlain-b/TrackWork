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
                LabeledContent {
                    Text("Unavailable")
                        .foregroundStyle(Color.ds.textSecondary)
                } label: {
                    Label("Background location", systemImage: "location.slash")
                }
            } header: {
                Text("Automatic Detection")
            } footer: {
                Text(
                    "Automatic location detection and permission requests are intentionally unavailable in this "
                        + "MVP build. Save places by entering coordinates or choosing a point on the map; manual "
                        + "attendance remains available."
                )
            }

            Section {
                placeRow(for: .home, place: homePlace)
                placeRow(for: .office, place: officePlace)
            } header: {
                Text("Places")
            } footer: {
                Text(locationTrackingService.statusDescription)
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
        return "Saved place · \(radius) m radius"
    }

}

#Preview {
    NavigationStack {
        LocationSetupView()
    }
    .modelContainer(PreviewData.modelContainer())
    .environment(LocationTrackingService())
}
