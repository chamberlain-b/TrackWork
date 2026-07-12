import SwiftUI

struct AddressSearchView: View {
    @Environment(\.dismiss) private var dismiss

    let onSelection: (PlaceSelection) -> Void

    @State private var query = ""
    @State private var results: [PlaceSearchResult] = []
    @State private var isSearching = false
    @State private var errorMessage: String?

    private let lookupService = PlaceLookupService()

    var body: some View {
        NavigationStack {
            Group {
                if isSearching && results.isEmpty {
                    ProgressView("Searching Apple Maps…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage, results.isEmpty {
                    ContentUnavailableView(
                        "Place not found",
                        systemImage: "mappin.slash",
                        description: Text(errorMessage)
                    )
                } else if results.isEmpty {
                    ContentUnavailableView(
                        "Search by address",
                        systemImage: "magnifyingglass",
                        description: Text("Enter a street address, building, or place name.")
                    )
                } else {
                    List(results) { result in
                        Button {
                            onSelection(result.selection)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                Text(result.title)
                                    .font(AppTypography.headline)
                                    .foregroundStyle(Color.ds.textPrimary)

                                Text(result.selection.formattedAddress)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(Color.ds.textSecondary)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, AppSpacing.xxs)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Find a Place")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Address or place")
            .searchPresentationToolbarBehavior(.avoidHidingContent)
            .onSubmit(of: .search) {
                Task { await search() }
            }
            .task(id: query) {
                guard query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3 else {
                    results = []
                    errorMessage = nil
                    return
                }

                do {
                    try await Task.sleep(for: .milliseconds(450))
                    await search()
                } catch is CancellationError {
                    return
                } catch {
                    return
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func search() async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return
        }

        isSearching = true
        errorMessage = nil
        defer { isSearching = false }

        do {
            results = try await lookupService.search(for: trimmedQuery)
        } catch is CancellationError {
            return
        } catch {
            results = []
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Apple Maps search is unavailable right now. Try again shortly."
        }
    }
}

#Preview {
    AddressSearchView { _ in }
}
