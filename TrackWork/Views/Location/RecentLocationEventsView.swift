#if DEBUG
import SwiftData
import SwiftUI

struct RecentLocationEventsView: View {
    @Query(sort: \LocationEvent.occurredAt, order: .reverse) private var events: [LocationEvent]

    private var recentEvents: [LocationEvent] {
        Array(events.prefix(50))
    }

    var body: some View {
        List {
            if recentEvents.isEmpty {
                ContentUnavailableView(
                    "No Location Events",
                    systemImage: "location.slash",
                    description: Text("Enter and exit events from saved Home and Office geofences will appear here in debug builds.")
                )
            } else {
                Section {
                    ForEach(recentEvents) { event in
                        eventRow(event)
                    }
                } header: {
                    Text("Recent Events")
                } footer: {
                    Text("Debug only. Default reports do not export raw location events or GPS coordinates.")
                }
            }
        }
        .navigationTitle("Location Events")
        .navigationBarTitleDisplayMode(.inline)
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

                Text(event.regionIdentifier)
                    .font(AppTypography.caption)
                    .foregroundStyle(Color.ds.textTertiary)
                    .lineLimit(1)
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
}

#Preview {
    NavigationStack {
        RecentLocationEventsView()
    }
    .modelContainer(PreviewData.modelContainer())
}
#endif
