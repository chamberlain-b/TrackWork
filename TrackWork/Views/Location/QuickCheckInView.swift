import SwiftData
import SwiftUI
import UIKit

struct QuickCheckInView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Place.typeRaw) private var places: [Place]
    @Query(sort: \AttendanceDay.date) private var attendanceDays: [AttendanceDay]
    @Query(sort: \LeaveRecord.date) private var leaveRecords: [LeaveRecord]
    @Query(sort: \PublicHoliday.date) private var publicHolidays: [PublicHoliday]
    @Query(sort: \CustomExcludedDay.date) private var customExcludedDays: [CustomExcludedDay]
    @Query(sort: \PlannedOfficeDay.date) private var plannedOfficeDays: [PlannedOfficeDay]
    @Query(sort: \ComplianceRule.createdAt) private var complianceRules: [ComplianceRule]

    @State private var locationService = LocationAuthorizationService()
    @State private var pendingResult: OneShotCheckInResult?
    @State private var resultMessage: String?
    @State private var saveError: String?

    private let checkInService = OneShotCheckInService()
    private let ruleResolver = ComplianceRuleResolver()
    private let calendar = Calendar.workTrackCalendar

    private var today: Date {
        calendar.startOfDay(for: .now)
    }

    private var activePlaces: [Place] {
        places.filter(\.isActive)
    }

    private var activeRule: ComplianceRule {
        ruleResolver.rule(for: today, from: complianceRules) ?? ComplianceRule()
    }

    var body: some View {
        List {
            if activePlaces.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Set up a place first",
                        systemImage: "mappin.slash",
                        description: Text("Save a home or office location first.")
                    )

                    NavigationLink {
                        LocationSetupView()
                    } label: {
                        Label("Set Up Locations", systemImage: "mappin.and.ellipse")
                    }
                }
            } else {
                Section {
                    Button {
                        pendingResult = nil
                        resultMessage = nil
                        saveError = nil
                        locationService.requestCurrentLocation()
                    } label: {
                        Label(
                            locationService.isRequestingLocation ? "Checking Location…" : "Check Location",
                            systemImage: "location.fill"
                        )
                    }
                    .disabled(locationService.isRequestingLocation)
                    .accessibilityIdentifier("quickCheckIn.locate")

                    if locationService.isRequestingLocation {
                        ProgressView("Checking location…")
                    }

                    if locationService.isPermissionDenied,
                       let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        Link("Open Location Settings", destination: settingsURL)
                    }
                } footer: {
                    Text("Uses one location sample, then discards it. Background tracking stays off.")
                }
            }

            if let pendingResult {
                Section("Result") {
                    Label(resultTitle(for: pendingResult), systemImage: resultIcon(for: pendingResult))
                        .foregroundStyle(pendingResult.canApplyToAttendance ? Color.ds.success : Color.ds.warning)

                    Text(resultExplanation(for: pendingResult))
                        .font(AppTypography.caption)
                        .foregroundStyle(Color.ds.textSecondary)

                    if pendingResult.canApplyToAttendance {
                        Button("Apply to Today", systemImage: "checkmark.circle.fill") {
                            applyToToday(pendingResult)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("quickCheckIn.apply")
                    }
                }
            }

            if let resultMessage {
                Section {
                    Label(resultMessage, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Color.ds.success)
                }
            }

            if let message = saveError ?? locationService.errorMessage {
                Section {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.ds.critical)
                }
            }
        }
        .navigationTitle("Check In")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: locationService.locationUpdateID) { _, _ in
            classifyCurrentLocation()
        }
    }

    private func classifyCurrentLocation() {
        guard let location = locationService.currentLocation else {
            return
        }

        pendingResult = checkInService.classify(location, against: activePlaces)
        locationService.discardCurrentLocation()
    }

    private func applyToToday(_ result: OneShotCheckInResult) {
        let existingDay = attendanceDays.first { calendar.isDate($0.date, inSameDayAs: today) }
        let protectedStatus = protectedClassificationForToday()
        let day = existingDay ?? AttendanceDay(
            date: today,
            finalClassification: protectedStatus ?? .unknown,
            complianceTreatment: ComplianceTreatmentResolver.resolve(
                classification: protectedStatus ?? .unknown,
                officeMinutes: 0,
                minimumOfficeMinutes: activeRule.minimumOfficeMinutes
            )
        )

        if existingDay == nil {
            modelContext.insert(day)
        }

        if let protectedStatus {
            day.finalClassificationRaw = protectedStatus.rawValue
            day.complianceTreatmentRaw = ComplianceTreatmentResolver.resolve(
                classification: protectedStatus,
                officeMinutes: day.officeMinutes,
                minimumOfficeMinutes: activeRule.minimumOfficeMinutes
            ).rawValue
        }

        let application = checkInService.apply(result, to: day)
        guard application != .notApplied else {
            saveError = "The check-in result could not be applied."
            return
        }

        plannedOfficeDays
            .filter { calendar.isDate($0.date, inSameDayAs: today) }
            .forEach(modelContext.delete)

        do {
            try modelContext.save()
            saveError = nil
            pendingResult = nil
            resultMessage = applicationMessage(application, result: result)
        } catch {
            modelContext.rollback()
            saveError = "Today’s check-in could not be saved. Try again."
        }
    }

    private func protectedClassificationForToday() -> AttendanceClassification? {
        if ActiveJurisdictionHolidayResolver.holiday(
            on: today,
            from: publicHolidays,
            jurisdictionId: activeRule.jurisdictionId,
            calendar: calendar
        ) != nil {
            return .publicHoliday
        }

        let leaveClassification = leaveRecords.first {
            calendar.isDate($0.date, inSameDayAs: today) && $0.duration == .fullDay
        }?.leaveType?.classification
        if let leaveClassification {
            return leaveClassification
        }

        if customExcludedDays.contains(where: { calendar.isDate($0.date, inSameDayAs: today) }) {
            return .nonWorkingDay
        }

        return nil
    }

    private func resultTitle(for result: OneShotCheckInResult) -> String {
        switch result.outcome {
        case .matched:
            "Matched \(result.matchedPlaceName ?? result.classification.displayName)"
        case .noActivePlaces:
            "No active places"
        case .outsideSavedPlaces:
            "Outside saved places"
        case .ambiguousMatches:
            "Overlapping place areas"
        case .invalidLocation:
            "Location unavailable"
        }
    }

    private func resultIcon(for result: OneShotCheckInResult) -> String {
        result.canApplyToAttendance ? "mappin.and.ellipse.circle.fill" : "exclamationmark.triangle.fill"
    }

    private func resultExplanation(for result: OneShotCheckInResult) -> String {
        switch result.outcome {
        case .matched:
            "Suggested status: \(result.classification.displayName)."
        case .noActivePlaces:
            "Enable a saved home or office place and try again."
        case .outsideSavedPlaces:
            "Not inside a saved area. Attendance was not changed."
        case .ambiguousMatches:
            "Matched both home and office. Adjust the saved areas."
        case .invalidLocation:
            "Location unavailable. Try again."
        }
    }

    private func applicationMessage(
        _ application: OneShotCheckInApplicationResult,
        result: OneShotCheckInResult
    ) -> String {
        switch application {
        case .appliedDetectedAndFinal:
            let placeName = result.matchedPlaceName ?? "your saved place"
            return "Today was recorded as \(result.classification.displayName) from \(placeName)."
        case .appliedDetectedPreservingManualFinal:
            return "Detected \(result.classification.displayName), while keeping your manual final status."
        case .appliedDetectedPreservingExcludedFinal:
            return "Detected \(result.classification.displayName), while keeping today’s leave, holiday, or exclusion."
        case .notApplied:
            return "No attendance was changed."
        }
    }
}

#Preview {
    NavigationStack {
        QuickCheckInView()
    }
    .modelContainer(PreviewData.modelContainer())
    .environment(LocationTrackingService())
}
