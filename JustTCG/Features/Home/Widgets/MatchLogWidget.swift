import SwiftUI
import SwiftData

struct MatchLogWidget: View {
    @Query(sort: \Match.date, order: .reverse) private var allMatches: [Match]
    @Query private var allDecks: [Deck]

    @State private var showLogMatch = false
    @State private var showDeckPicker = false
    @State private var selectedDeck: Deck? = nil

    private var recentMatches: [Match] { Array(allMatches.prefix(5)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
            Divider()
            if recentMatches.isEmpty {
                Text("No matches yet — log your first game.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                    .padding(.horizontal)
                    .padding(.vertical, 14)
            } else {
                ForEach(recentMatches) { match in
                    matchRow(match)
                    if match.id != recentMatches.last?.id {
                        Divider().padding(.leading)
                    }
                }
            }
            Divider()
            seeAllRow
        }
        .background(.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .onAppear(perform: resolveLastDeck)
        .sheet(isPresented: $showDeckPicker, onDismiss: {
            if selectedDeck != nil { showLogMatch = true }
        }) {
            DeckPickerSheet(decks: allDecks) { deck in
                selectedDeck = deck
                showDeckPicker = false
            }
        }
        .sheet(isPresented: $showLogMatch, onDismiss: resolveLastDeck) {
            if let deck = selectedDeck {
                LogMatchSheet(deck: deck)
            }
        }
    }

    // MARK: - Subviews

    private var headerRow: some View {
        HStack {
            Text("Recent Matches")
                .font(.headline)
            Spacer()
            Button("Log Match") {
                if let deck = selectedDeck {
                    _ = deck
                    showLogMatch = true
                } else {
                    showDeckPicker = true
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    private var seeAllRow: some View {
        NavigationLink {
            AllMatchHistoryView()
        } label: {
            Text("See All")
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.vertical, 12)
        }
    }

    @ViewBuilder
    private func matchRow(_ match: Match) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(match.deck?.name ?? "Unknown Deck")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(match.opponentArchetype)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            resultCapsule(match.result)
            Text(match.date, format: .relative(presentation: .named))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func resultCapsule(_ result: MatchResult) -> some View {
        let (label, color): (String, Color) = switch result {
        case .win:  ("W", .green)
        case .loss: ("L", .red)
        case .tie:  ("T", .secondary)
        }
        Text(label)
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(color))
    }

    // MARK: - Helpers

    private func resolveLastDeck() {
        guard let idString = UserDefaults.standard.string(forKey: "last_deck_id"),
              let id = UUID(uuidString: idString) else {
            selectedDeck = nil
            return
        }
        selectedDeck = allDecks.first { $0.id == id }
    }
}

// MARK: - Deck picker sheet

private struct DeckPickerSheet: View {
    let decks: [Deck]
    let onSelect: (Deck) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(decks) { deck in
                Button(deck.name) { onSelect(deck) }
                    .foregroundStyle(.primary)
            }
            .navigationTitle("Select Deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .overlay {
                if decks.isEmpty {
                    ContentUnavailableView(
                        "No Decks",
                        systemImage: "rectangle.stack",
                        description: Text("Create a deck first to log a match.")
                    )
                }
            }
        }
    }
}

// MARK: - All match history (global, across all decks)

struct AllMatchHistoryView: View {
    @Query(sort: \Match.date, order: .reverse) private var matches: [Match]

    var body: some View {
        List(matches) { match in
            MatchRow(match: match)
        }
        .navigationTitle("Match History")
        .navigationBarTitleDisplayMode(.large)
        .overlay {
            if matches.isEmpty {
                ContentUnavailableView(
                    "No Matches Yet",
                    systemImage: "sportscourt",
                    description: Text("Log a match to start tracking your results.")
                )
            }
        }
    }
}
