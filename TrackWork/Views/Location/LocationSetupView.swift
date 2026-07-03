import CoreLocation
import SwiftData
import SwiftUI
import UIKit

struct LocationSetupView: View {
    @Environment(\.openURL) private var openURL
    @Environment(LocationTrackingService.self) private var locationTrackingService
    @Query(sort: \Place.typeRaw) private var places: [Place]
    @State private var locationAuthorizationService = LocationAuthorizationService(automaticBackgroundTrackingEnabled: true)

    private var homePlace: Place? {
        place(for: .home)
    }

    private var officePlace: Place? {
        place(for: .office)
    }

    var body: some View {
        List {
            Section {
                permissionStatusRow

                Button {
                    locationAuthorizationService.requestWhenInUseAuthorization()
                } label: {
                    Label("Allow While Using App", systemImage: "location")
                }
                .disabled(!locationAuthorizationService.canRequestWhenInUseAuthorization || locationAuthorizationService.isRequestingAuthorization)
                .accessibilityIdentifier("locationAuthorization.requestWhenInUse")

                if shouldShowSettingsLink {
                    Button {
                        openAppSettings()
                    } label: {
                        Label("Open iOS Settings", systemImage: "gearshape")
                    }
                    .accessibilityIdentifier("locationAuthorization.openSettings")
                }
            } header: {
                Text("Location Access")
            } footer: {
                Text("Work Track uses location only after you choose to allow it. Saved home and office places can be monitored with geofences; manual attendance still works without permission.")
            }

            Section {
                Button {
                    locationAuthorizationService.requestAlwaysAuthorizationIfAvailable()
                } label: {
                    Label("Allow Background Location", systemImage: "location.fill")
                }
                .disabled(!locationAuthorizationService.canRequestAlwaysAuthorization || locationAuthorizationService.isRequestingAuthorization)
                .accessibilityIdentifier("locationAuthorization.requestAlways")
            } header: {
                Text("Background Access")
            } footer: {
                Text("Background location access lets iOS deliver home and office geofence events when Work Track is not open. This uses region monitoring, not continuous GPS.")
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
            locationAuthorizationService.refreshAuthorizationStatus()
            locationTrackingService.refreshMonitoring(for: places)
        }
        .onChange(of: authorizationStatus) { _, _ in
            locationTrackingService.refreshMonitoring(for: places)
        }
    }

    private var permissionStatusRow: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: statusSystemImage)
                .foregroundStyle(statusIconColor)
                .frame(width: 32, height: 32)
                .background(statusIconColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.xs, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Permission")
                        .font(AppTypography.headline)
                        .foregroundStyle(Color.ds.textPrimary)

                    Spacer()

                    DSStatusPill(
                        text: statusTitle,
                        style: statusPillStyle
                    )
                }

                Text(statusDescription)
                    .font(AppTypography.caption)
                    .foregroundStyle(Color.ds.textSecondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("locationAuthorization.status")
    }

    private var authorizationStatus: CLAuthorizationStatus {
        locationAuthorizationService.authorizationStatus
    }

    private var shouldShowSettingsLink: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    private var statusTitle: String {
        switch authorizationStatus {
        case .notDetermined:
            "Not requested"
        case .restricted:
            "Restricted"
        case .denied:
            "Denied"
        case .authorizedAlways:
            "Always allowed"
        case .authorizedWhenInUse:
            "Allowed while using"
        @unknown default:
            "Unknown"
        }
    }

    private var statusDescription: String {
        switch authorizationStatus {
        case .notDetermined:
            "Location access has not been requested. Work Track will ask only when you choose to enable it."
        case .restricted:
            "Location access is restricted on this device. Check Screen Time, device management, or parental controls."
        case .denied:
            "Location access is off for Work Track. You can change this later in iOS Settings."
        case .authorizedAlways:
            "Work Track can use location in the background, but automatic tracking is not active yet."
        case .authorizedWhenInUse:
            "Work Track can use location while the app is open. Background tracking has a separate later step."
        @unknown default:
            "Work Track cannot identify the current location permission state."
        }
    }

    private var statusSystemImage: String {
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            "checkmark.circle.fill"
        case .denied, .restricted:
            "exclamationmark.triangle.fill"
        case .notDetermined:
            "location.circle"
        @unknown default:
            "questionmark.circle"
        }
    }

    private var statusPillStyle: DSStatusPillStyle {
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            .success
        case .denied, .restricted:
            .warning
        case .notDetermined:
            .neutral
        @unknown default:
            .neutral
        }
    }

    private var statusIconColor: Color {
        switch statusPillStyle {
        case .success:
            Color.ds.success
        case .warning:
            Color.ds.warning
        case .critical:
            Color.ds.critical
        case .info:
            Color.ds.info
        case .neutral:
            Color.ds.textTertiary
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

    private func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            return
        }

        openURL(settingsURL)
    }
}

#Preview {
    NavigationStack {
        LocationSetupView()
    }
    .modelContainer(PreviewData.modelContainer())
    .environment(LocationTrackingService())
}
