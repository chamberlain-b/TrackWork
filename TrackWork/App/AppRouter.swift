import SwiftData
import SwiftUI

struct AppRouter: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Place.typeRaw) private var places: [Place]
    @Query(sort: \ComplianceRule.createdAt) private var complianceRules: [ComplianceRule]
    @State private var locationTrackingService = LocationTrackingService()
    @State private var privacyLockService = AppPrivacyLockService()
    @State private var holidaySyncError: String?

    private let holidaySyncService = HolidaySyncService()
    private let ruleResolver = ComplianceRuleResolver()

    @MainActor
    private var placeMonitoringSignature: [PlaceMonitoringSignature] {
        places.map(PlaceMonitoringSignature.init)
    }

    private var holidayRuleSignature: HolidayRuleSignature {
        let rule = ruleResolver.currentRule(from: complianceRules)
        return HolidayRuleSignature(
            countryCode: rule?.countryCode ?? Country.australia.rawValue,
            jurisdictionId: rule?.jurisdictionId ?? "AU-VIC"
        )
    }

    var body: some View {
        ZStack {
            ContentView()
                .environment(locationTrackingService)
                .environment(privacyLockService)

            if privacyLockService.isContentObscured {
                PrivacyShieldView(
                    isUnlocking: privacyLockService.isAuthenticating,
                    errorMessage: privacyLockService.errorMessage,
                    onUnlock: unlock
                )
                .transition(.opacity)
                .zIndex(10)
            }
        }
            .animation(.easeInOut(duration: 0.16), value: privacyLockService.isContentObscured)
            .task {
                if !AppLaunchConfiguration.isUITesting {
                    // Configure the on-device event journal before authentication can delay the UI.
                    locationTrackingService.configure(modelContext: modelContext)
                    locationTrackingService.refreshMonitoring(for: places)
                }

                await privacyLockService.unlockIfNeeded()
            }
            .onChange(of: placeMonitoringSignature) { _, _ in
                guard !AppLaunchConfiguration.isUITesting else {
                    return
                }

                locationTrackingService.refreshMonitoring(for: places)
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:
                    Task { await privacyLockService.unlockIfNeeded() }
                case .inactive:
                    privacyLockService.obscureWhileInactive()
                case .background:
                    privacyLockService.lockAndObscure()
                @unknown default:
                    privacyLockService.lockAndObscure()
                }
            }
            .task(id: holidayRuleSignature) {
                guard !AppLaunchConfiguration.isUITesting else {
                    return
                }

                bootstrapHolidays()
            }
            .alert(
                "Holiday data unavailable",
                isPresented: Binding(
                    get: { holidaySyncError != nil },
                    set: { isPresented in
                        if !isPresented {
                            holidaySyncError = nil
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {
                    holidaySyncError = nil
                }
            } message: {
                Text(holidaySyncError ?? "The bundled holiday calendar could not be loaded.")
            }
    }

    private func bootstrapHolidays() {
        let rule = activeRule()
        guard let country = rule.country else {
            holidaySyncError = "The selected country is not supported."
            return
        }

        let currentYear = Calendar.current.component(.year, from: .now)
        do {
            try holidaySyncService.sync(
                country: country,
                jurisdictionId: rule.jurisdictionId,
                years: HolidayCoverage.supportedYears,
                in: modelContext
            )
            holidaySyncError = HolidayCoverage.validation(forYear: currentYear).userFacingMessage
        } catch {
            holidaySyncError = error.localizedDescription
        }
    }

    private func activeRule() -> ComplianceRule {
        if let rule = ruleResolver.currentRule(from: complianceRules) {
            return rule
        }

        let rule = ComplianceRule()
        modelContext.insert(rule)
        try? modelContext.save()
        return rule
    }

    private func unlock() {
        Task {
            await privacyLockService.unlockIfNeeded()
        }
    }
}

private struct PrivacyShieldView: View {
    let isUnlocking: Bool
    let errorMessage: String?
    let onUnlock: () -> Void

    var body: some View {
        ZStack {
            Color.ds.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.lg) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(Color.ds.accentPrimary)
                    .accessibilityHidden(true)

                VStack(spacing: AppSpacing.xs) {
                    Text("Work Track is locked")
                        .font(AppTypography.title)
                        .foregroundStyle(Color.ds.textPrimary)

                    Text("Authenticate to view your private attendance data.")
                        .font(AppTypography.body)
                        .foregroundStyle(Color.ds.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Button(action: onUnlock) {
                    if isUnlocking {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Unlock", systemImage: "faceid")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isUnlocking)
                .accessibilityIdentifier("privacyLock.unlock")

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(AppTypography.caption)
                        .foregroundStyle(Color.ds.critical)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(AppSpacing.xl)
            .frame(maxWidth: 420)
        }
        .accessibilityAddTraits(.isModal)
    }
}

private struct PlaceMonitoringSignature: Equatable {
    let id: UUID
    let typeRaw: String
    let latitude: Double
    let longitude: Double
    let radiusMeters: Double
    let isActive: Bool

    init(place: Place) {
        self.id = place.id
        self.typeRaw = place.typeRaw
        self.latitude = place.latitude
        self.longitude = place.longitude
        self.radiusMeters = place.radiusMeters
        self.isActive = place.isActive
    }
}

private struct HolidayRuleSignature: Equatable {
    let countryCode: String
    let jurisdictionId: String
}

#Preview {
    AppRouter()
        .modelContainer(PreviewData.modelContainer())
}
