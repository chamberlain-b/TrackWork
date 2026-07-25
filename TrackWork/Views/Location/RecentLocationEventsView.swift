import SwiftData
import SwiftUI

struct RecentLocationEventsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LocationTrackingService.self) private var locationTrackingService
    @Query(sort: \LocationEvent.occurredAt, order: .reverse) private var events: [LocationEvent]
    @State private var isShowingClearConfirmation = false
    @State private var clearError: String?

    var body: some View {
        List {
            if events.isEmpty {
                ContentUnavailableView(
                    "No Location Events",
                    systemImage: "location.slash",
                    description: Text(
                        "Automatic Attendance events appear here."
                    )
                )
            } else {
                Section {
                    ForEach(events) { event in
                        eventRow(event)
                    }
                } header: {
                    Text("Recent Events")
                } footer: {
                    Text("Stored on this device. Excluded from standard reports and backups.")
                }
            }

            if let clearError {
                Section {
                    Label(clearError, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.ds.critical)
                }
            }
        }
        .navigationTitle("Location Events")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !events.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button("Clear", systemImage: "trash", role: .destructive) {
                        isShowingClearConfirmation = true
                    }
                    .accessibilityIdentifier("locationEvents.clear")
                }
            }
        }
        .alert("Clear all location events?", isPresented: $isShowingClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear Events", role: .destructive, action: clearEvents)
        } message: {
            Text("Deletes entry and exit events. Attendance records remain.")
        }
    }

    private func eventRow(_ event: LocationEvent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: event.eventKind?.systemImageName ?? "location.circle.fill")
                .foregroundStyle(iconColor(for: event))
                .frame(width: 32, height: 32)
                .background(iconColor(for: event).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.xs, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title(for: event))
                        .font(AppTypography.headline)
                        .foregroundStyle(Color.ds.textPrimary)

                    Spacer()

                    Text(event.occurredAt, style: .time)
                        .font(AppTypography.caption)
                        .foregroundStyle(Color.ds.textSecondary)
                }

                Text(event.occurredAt, format: .dateTime.year().month().day().hour().minute())
                    .font(AppTypography.caption)
                    .foregroundStyle(Color.ds.textSecondary)

            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func title(for event: LocationEvent) -> String {
        let action = event.eventKind?.displayName ?? "Recorded"
        let placeName = event.placeName.isEmpty ? (event.placeType?.displayName ?? "Place") : event.placeName
        return "\(action) \(placeName)"
    }

    private func iconColor(for event: LocationEvent) -> Color {
        switch event.placeType {
        case .home:
            Color.ds.info
        case .office:
            Color.ds.accentPrimary
        case nil:
            Color.ds.textTertiary
        }
    }

    private func clearEvents() {
        events.forEach(modelContext.delete)
        do {
            try modelContext.save()
            locationTrackingService.reseedCurrentRegionStates()
            clearError = nil
        } catch {
            modelContext.rollback()
            clearError = "Location events could not be cleared. Try again."
        }
    }
}

#Preview {
    NavigationStack {
        RecentLocationEventsView()
    }
    .modelContainer(PreviewData.modelContainer())
    .environment(LocationTrackingService())
}
