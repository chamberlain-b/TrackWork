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

    private var hasActivePlaces: Bool {
        places.contains { $0.isActive && $0.type != nil }
    }

    var body: some View {
        List {
            Section {
                placeRow(for: .home, place: homePlace)
                placeRow(for: .office, place: officePlace)
            } header: {
                Text("Places")
            } footer: {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Locations are optional. Choose an address or map point for Check In or Automatic Attendance. Saved locations stay on this device.")
                    Text("Manual attendance works without saved locations or location access.")
                        .accessibilityIdentifier("locationSetup.manualAttendance")
                }
            }

            if hasActivePlaces {
                Section {
                    NavigationLink {
                        QuickCheckInView()
                    } label: {
                        Label("Check In", systemImage: "location.circle.fill")
                    }
                    .accessibilityIdentifier("locationSetup.quickCheckIn")
                } footer: {
                    Text("Check In compares one location sample with your saved places.")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .appScreenBackground()
        .navigationTitle("Locations")
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
                    .foregroundStyle(Color.ds.textInverse)
                    .frame(width: 32, height: 32)
                    .background(place?.isActive == true ? Color.ds.success : Color.ds.textTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.xs, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(placeType.displayName)
                        .font(AppTypography.headline)
                        .foregroundStyle(Color.ds.textPrimary)

                    Text(summary(for: place))
                        .font(AppTypography.caption)
                        .foregroundStyle(Color.ds.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
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
            return "Not saved"
        }

        let radius = place.radiusMeters.formatted(.number.precision(.fractionLength(0)))
        let area = "\(place.displayAddress) · \(radius) m area"
        return place.isActive ? area : "Inactive · \(area)"
    }

}

#Preview {
    NavigationStack {
        LocationSetupView()
    }
    .modelContainer(PreviewData.modelContainer())
    .environment(LocationTrackingService())
}
