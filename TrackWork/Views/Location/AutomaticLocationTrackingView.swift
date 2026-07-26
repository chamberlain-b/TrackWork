import CoreLocation
import SwiftData
import SwiftUI
import UIKit

struct AutomaticLocationTrackingView: View {
    @Environment(LocationTrackingService.self) private var trackingService
    @Query(sort: \Place.typeRaw) private var places: [Place]

    @State private var actionMessage: String?

    private var activePlaces: [Place] {
        places.filter(\.isActive)
    }

    var body: some View {
        List {
            Section {
                Label(statusTitle, systemImage: statusSystemImage)
                    .foregroundStyle(statusColor)
                    .accessibilityIdentifier("automaticTracking.status")

                Text(statusDetail)
                    .font(AppTypography.caption)
                    .foregroundStyle(Color.ds.textSecondary)

                if trackingService.isAutomaticTrackingEnabled {
                    Button("Turn Off", systemImage: "location.slash", role: .destructive) {
                        trackingService.setAutomaticTrackingEnabled(false, for: places)
                        actionMessage = "Automatic Attendance is off."
                    }
                    .accessibilityIdentifier("automaticTracking.disable")
                } else if !activePlaces.isEmpty {
                    setupAction
                }

                if let actionMessage {
                    Text(actionMessage)
                        .font(AppTypography.caption)
                        .foregroundStyle(Color.ds.textSecondary)
                }
            } header: {
                Text("Status")
            } footer: {
                Text(statusFooter)
            }

            if activePlaces.isEmpty {
                Section {
                    NavigationLink {
                        LocationSetupView()
                    } label: {
                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            Label("Add a home or office", systemImage: "mappin.and.ellipse")
                                .font(AppTypography.headline)

                            Text("Define where attendance can be detected.")
                                .font(AppTypography.caption)
                                .foregroundStyle(Color.ds.textSecondary)
                        }
                        .padding(.vertical, AppSpacing.xxs)
                    }
                    .accessibilityIdentifier("automaticTracking.setupPlaces")
                } header: {
                    Text("Get Started")
                }
            } else {
                Section("Saved Areas") {
                    ForEach(activePlaces) { place in
                        LabeledContent {
                            Text("\(place.radiusMeters.formatted(.number.precision(.fractionLength(0)))) m")
                        } label: {
                            Label(place.name, systemImage: place.type?.systemImageName ?? "mappin")
                        }
                    }
                }
            }

            Section {
                Label(
                    "Uses saved-area boundaries, not continuous GPS.",
                    systemImage: "location.square"
                )
                Label(
                    "Manual changes always take priority.",
                    systemImage: "hand.tap.fill"
                )
                Label(
                    "iOS may delay some boundary events.",
                    systemImage: "exclamationmark.triangle.fill"
                )

                NavigationLink {
                    RecentLocationEventsView()
                } label: {
                    Label("Location Events", systemImage: "list.bullet.rectangle")
                }
                .accessibilityIdentifier("automaticTracking.events")
            } header: {
                Text("Privacy and Control")
            } footer: {
                Text("Location events stay on this device and are excluded from standard reports.")
            }
        }
        .navigationTitle("Automatic Attendance")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            trackingService.refreshAuthorizationStatus()
            trackingService.refreshMonitoring(for: places)
        }
        .onChange(of: placeSignature) { _, _ in
            trackingService.refreshMonitoring(for: places)
        }
    }

    @ViewBuilder
    private var setupAction: some View {
        switch trackingService.authorizationStatus {
        case .notDetermined:
            Button("Allow While Using App", systemImage: "location.fill") {
                actionMessage = nil
                trackingService.requestForegroundAuthorizationForAutomation()
            }
            .disabled(activePlaces.isEmpty)
            .accessibilityIdentifier("automaticTracking.requestWhenInUse")

        case .authorizedWhenInUse:
            Button("Allow Always Access", systemImage: "location.badge.checkmark") {
                actionMessage = nil
                trackingService.requestAlwaysAuthorizationForAutomation()
            }
            .disabled(activePlaces.isEmpty)
            .accessibilityIdentifier("automaticTracking.requestAlways")

        case .authorizedAlways:
            Button("Turn On", systemImage: "location.viewfinder") {
                let enabled = trackingService.setAutomaticTrackingEnabled(true, for: places)
                actionMessage = enabled
                    ? "Automatic Attendance is on."
                    : trackingService.statusDescription
            }
            .disabled(activePlaces.isEmpty)
            .accessibilityIdentifier("automaticTracking.enable")

        case .denied, .restricted:
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                Link(destination: settingsURL) {
                    Label("Open iOS Location Settings", systemImage: "gear")
                }
            }

        @unknown default:
            Text("Location permission is unavailable. Manual attendance still works.")
                .font(AppTypography.caption)
                .foregroundStyle(Color.ds.textSecondary)
        }
    }

    @MainActor
    private var placeSignature: [AutomaticTrackingPlaceSignature] {
        places.map(AutomaticTrackingPlaceSignature.init)
    }

    private var statusTitle: String {
        if trackingService.isAutomaticTrackingEnabled {
            if case .monitoring(let count) = trackingService.trackingStatus {
                return "Monitoring \(count) saved area\(count == 1 ? "" : "s")"
            }
            return "Automation needs attention"
        }

        if activePlaces.isEmpty {
            return "Not set up"
        }

        return "Automatic attendance is off"
    }

    private var statusDetail: String {
        if trackingService.isAutomaticTrackingEnabled {
            return trackingService.statusDescription
        }

        if activePlaces.isEmpty {
            return "No places or location access configured."
        }

        switch trackingService.authorizationStatus {
        case .notDetermined:
            return "Your places are ready. Allow location access to continue."
        case .authorizedWhenInUse:
            return "Allow Always access so iOS can detect arrivals in the background."
        case .authorizedAlways:
            return "Location access is ready. Turn on automatic attendance when you’re ready."
        case .denied, .restricted:
            return "Location access is off. Manual attendance still works."
        @unknown default:
            return "Location permission is unavailable. Manual attendance still works."
        }
    }

    private var statusFooter: String {
        activePlaces.isEmpty
            ? "Nothing is tracked until you finish setup."
            : "Background attendance requires Always location access."
    }

    private var statusSystemImage: String {
        if case .monitoring = trackingService.trackingStatus {
            return "checkmark.circle.fill"
        }

        if activePlaces.isEmpty {
            return "mappin.and.ellipse"
        }

        return trackingService.isAutomaticTrackingEnabled
            ? "exclamationmark.triangle.fill"
            : "location.slash"
    }

    private var statusColor: Color {
        if case .monitoring = trackingService.trackingStatus {
            return Color.ds.success
        }

        if activePlaces.isEmpty {
            return Color.ds.accentPrimary
        }

        return trackingService.isAutomaticTrackingEnabled ? Color.ds.warning : Color.ds.textSecondary
    }
}

private struct AutomaticTrackingPlaceSignature: Equatable {
    let id: UUID
    let latitude: Double
    let longitude: Double
    let radiusMeters: Double
    let isActive: Bool

    init(_ place: Place) {
        id = place.id
        latitude = place.latitude
        longitude = place.longitude
        radiusMeters = place.radiusMeters
        isActive = place.isActive
    }
}

#Preview {
    NavigationStack {
        AutomaticLocationTrackingView()
    }
    .modelContainer(PreviewData.modelContainer())
    .environment(LocationTrackingService())
}
