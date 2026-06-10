import SwiftUI

/// Presented from the Cards view long-press context menu.
/// Fetches competitive tournament decks that use the selected card,
/// lets the user pick one, then opens ImportDeckSheet pre-loaded with the
/// formatted deck list so they can review and swap cards before importing.
struct CardCompetitiveDeckSheet: View {
    let card: CachedCard

    @Environment(\.dismiss) private var dismiss

    @State private var phase: Phase = .loadingList
    /// Full fetched list preserved so dismissing the import sheet restores all results.
    @State private var fetchedPlacements: [LimitlessPlacement] = []

    private let client = LimitlessTCGClient()

    enum Phase {
        case loadingList
        case empty                            // no competitive decks found
        case list([LimitlessPlacement])       // ready to pick
        case loadingDeck(LimitlessPlacement)  // fetching the chosen deck
        case readyToImport(String, LimitlessPlacement)  // (deckListText, placement)
        case error(String)
    }

    var body: some View {
        NavigationStack {
            phaseView
                .navigationTitle(navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") { dismiss() }
                    }
                }
        }
        .task { await fetchDecklists() }
        // ImportDeckSheet is presented on top once we have the deck text.
        .sheet(isPresented: isImportSheetPresented) {
            if case .readyToImport(let text, let placement) = phase {
                ImportDeckSheet(
                    deckListText: text,
                    initialDeckName: placement.archetype + " Deck",
                    onImportCompleted: { dismiss() }
                )
            }
        }
    }

    // MARK: - Derived bindings

    private var isImportSheetPresented: Binding<Bool> {
        Binding(
            get: { if case .readyToImport = phase { return true }; return false },
            set: { if !$0 { phase = .list(fetchedPlacements) } }
        )
    }

    private var navigationTitle: String {
        switch phase {
        case .readyToImport(_, let p): return p.archetype
        default: return "\(card.name) Decks"
        }
    }

    // MARK: - Phase view

    @ViewBuilder
    private var phaseView: some View {
        switch phase {
        case .loadingList:
            statusView(icon: nil, message: "Finding competitive decks…", showSpinner: true)

        case .empty:
            statusView(
                icon: "rectangle.stack.badge.minus",
                message: "No decks available at this time",
                showSpinner: false
            )

        case .list(let placements):
            deckListView(placements)

        case .loadingDeck:
            statusView(icon: nil, message: "Loading deck…", showSpinner: true)

        case .readyToImport:
            // The ImportDeckSheet sheet overlay handles this — show a spinner briefly
            statusView(icon: nil, message: "Opening deck…", showSpinner: true)

        case .error(let message):
            statusView(icon: "wifi.exclamationmark", message: message, showSpinner: false)
        }
    }

    private func statusView(icon: String?, message: String, showSpinner: Bool) -> some View {
        VStack(spacing: 14) {
            if showSpinner {
                ProgressView()
            } else if let icon {
                Image(systemName: icon)
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
            }
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func deckListView(_ placements: [LimitlessPlacement]) -> some View {
        List(placements) { placement in
            Button {
                Task { await selectDeck(placement) }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(placement.archetype)
                        .font(.body)
                    HStack(spacing: 6) {
                        Text(placement.playerName)
                        if let tournament = placement.tournamentName {
                            Text("·")
                            Text(tournament)
                        }
                        Text("·")
                        Text("#\(placement.rank)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
            .foregroundStyle(.primary)
        }
        .listStyle(.plain)
    }

    // MARK: - Async actions

    @MainActor
    private func fetchDecklists() async {
        phase = .loadingList
        do {
            let all = try await client.fetchCardDecklists(
                setCode: card.setCode,
                number: card.number
            )
            let withLists = all.filter { $0.deckListId != nil }
            fetchedPlacements = withLists
            phase = withLists.isEmpty ? .empty : .list(withLists)
        } catch {
            phase = .error((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    @MainActor
    private func selectDeck(_ placement: LimitlessPlacement) async {
        guard let listId = placement.deckListId else { return }
        phase = .loadingDeck(placement)
        do {
            let deckList = try await client.fetchDeckList(listId: listId)
            let text = LimitlessDeckFormatter.toPTCGL(deckList)
            phase = .readyToImport(text, placement)
        } catch {
            phase = .error((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }
}
