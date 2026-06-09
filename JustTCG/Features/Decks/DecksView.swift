import SwiftUI
import SwiftData

struct DecksView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Deck.updatedAt, order: .reverse) private var decks: [Deck]
    @Query private var allCards: [CachedCard]
    @AppStorage("deckRowCoverCardCount") private var coverCardCount: Int = 2

    @State private var deckToDelete: Deck? = nil
    @State private var deckToRename: Deck? = nil
    @State private var deckForCoverPicker: Deck? = nil
    @State private var deckForStatus: Deck? = nil
    @State private var renameText = ""
    @State private var showNewDeckSheet = false
    @State private var showImportSheet = false
    @State private var showRetired = false
    @State private var showDeckGenerator = false

    private var cardMap: [String: CachedCard] {
        Dictionary(uniqueKeysWithValues: allCards.map { ($0.id, $0) })
    }

    private var visibleDecks: [Deck] {
        showRetired ? decks : decks.filter { $0.status != .retired }
    }

    var body: some View {
        NavigationStack {
            Group {
                if visibleDecks.isEmpty {
                    emptyState
                } else {
                    deckList
                }
            }
            .navigationTitle("Decks")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        showRetired.toggle()
                    } label: {
                        Image(systemName: showRetired ? "archivebox.fill" : "archivebox")
                    }
                    .tint(showRetired ? .primary : .secondary)
                    Button { showDeckGenerator = true } label: {
                        Image(systemName: "wand.and.stars")
                    }
                    Button { showImportSheet = true } label: {
                        Image(systemName: "arrow.down.doc")
                    }
                    Button { showNewDeckSheet = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .fullScreenCover(isPresented: $showDeckGenerator) {
                DeckGeneratorView()
            }
            .confirmationDialog(
                "Change Status",
                isPresented: Binding(
                    get: { deckForStatus != nil },
                    set: { if !$0 { deckForStatus = nil } }
                ),
                presenting: deckForStatus
            ) { deck in
                Button("Building") {
                    DeckRepository(modelContext: context).setStatus(.building, for: deck)
                    deckForStatus = nil
                }
                Button("Playing") {
                    DeckRepository(modelContext: context).setStatus(.playing, for: deck)
                    deckForStatus = nil
                }
                Button("Retired") {
                    DeckRepository(modelContext: context).setStatus(.retired, for: deck)
                    deckForStatus = nil
                }
                Button("Cancel", role: .cancel) { deckForStatus = nil }
            } message: { deck in
                Text("Set status for \"\(deck.name)\"")
            }
            .alert(
                "Delete Deck",
                isPresented: Binding(
                    get: { deckToDelete != nil },
                    set: { if !$0 { deckToDelete = nil } }
                ),
                presenting: deckToDelete
            ) { deck in
                Button("Delete", role: .destructive) {
                    DeckRepository(modelContext: context).deleteDeck(deck)
                    deckToDelete = nil
                }
                Button("Cancel", role: .cancel) {}
            } message: { deck in
                Text("Delete \"\(deck.name)\"? This cannot be undone.")
            }
            .alert(
                "Rename Deck",
                isPresented: Binding(
                    get: { deckToRename != nil },
                    set: { if !$0 { deckToRename = nil } }
                ),
                presenting: deckToRename
            ) { deck in
                TextField("Deck name", text: $renameText)
                Button("Save") {
                    let trimmed = renameText.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        DeckRepository(modelContext: context).renameDeck(deck, to: trimmed)
                    }
                    deckToRename = nil
                }
                Button("Cancel", role: .cancel) { deckToRename = nil }
            } message: { deck in
                Text("Enter a new name for \"\(deck.name)\".")
            }
            .sheet(isPresented: $showNewDeckSheet) {
                DeckDetailView(mode: .create)
            }
            .sheet(isPresented: $showImportSheet) {
                ImportDeckSheet()
            }
            .sheet(item: $deckForCoverPicker) { deck in
                CoverCardPickerSheet(deck: deck, cardMap: cardMap)
            }
        }
    }

    // MARK: - Sub-views

    private var deckList: some View {
        List {
            ForEach(visibleDecks) { deck in
                NavigationLink(destination: DeckDetailView(mode: .edit(deck))) {
                    DeckRowView(deck: deck, cardMap: cardMap, coverCardCount: coverCardCount)
                }
                .listRowInsets(EdgeInsets(top: 16, leading: 8, bottom: 16, trailing: 16))
                .alignmentGuide(.listRowSeparatorLeading) { d in d[.leading] }
                .opacity(deck.status == .retired ? 0.55 : 1)
                .swipeActions(edge: .leading) {
                    Button {
                        renameText = deck.name
                        deckToRename = deck
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    .tint(.orange)
                    Button {
                        deckForCoverPicker = deck
                    } label: {
                        Label("Cover", systemImage: "photo.on.rectangle")
                    }
                    .tint(.blue)
                    Button {
                        deckForStatus = deck
                    } label: {
                        Label("Status", systemImage: "flag")
                    }
                    .tint(.purple)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        deckToDelete = deck
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No decks yet")
                .font(.title3.bold())
            Text("Tap + to create your first deck.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Deck row

private struct DeckRowView: View {
    let deck: Deck
    let cardMap: [String: CachedCard]
    let coverCardCount: Int

    private var cardCount: Int {
        deck.cards.reduce(0) { $0 + $1.quantity }
    }

    private var totalMatches: Int { deck.matches.count }
    private var wins: Int { deck.matches.filter { $0.result == .win }.count }
    private var winRate: Int? {
        guard totalMatches > 0 else { return nil }
        return Int(Double(wins) / Double(totalMatches) * 100)
    }

    private var covers: [CachedCard] {
        coverCards(for: deck, in: cardMap, count: coverCardCount)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 40) {
            if !covers.isEmpty {
                thumbnailStack(covers)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(deck.name)
                        .font(.headline)
                    StatusBadge(status: deck.status)
                }
                HStack(spacing: 0) {
                    Text("\(cardCount)/60")
                        .foregroundStyle(cardCount == 60 ? .primary : .secondary)
                    if let pct = winRate {
                        Text("  ·  ")
                            .foregroundStyle(.secondary)
                        Text("\(pct)%")
                            .foregroundStyle(pct >= 50 ? .primary : .secondary)
                        Text("  ·  \(totalMatches) games")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func thumbnailStack(_ cards: [CachedCard]) -> some View {
        let fixedWidth = 44 + CGFloat(max(coverCardCount - 1, 0)) * 18
        ZStack(alignment: .leading) {
            ForEach(Array(cards.enumerated().reversed()), id: \.offset) { index, card in
                AsyncImage(url: URL(string: card.imageURL)) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 4).fill(.quaternary)
                }
                .frame(width: 44, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .offset(x: CGFloat(index) * 18)
            }
        }
        .frame(width: fixedWidth, height: 60)
    }
}

// MARK: - Status badge

private struct StatusBadge: View {
    let status: DeckStatus

    private var color: Color {
        switch status {
        case .building: return .orange
        case .playing:  return .green
        case .retired:  return .secondary
        }
    }

    var body: some View {
        Text(status.label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: Capsule())
    }
}

private func coverCards(for deck: Deck, in cardMap: [String: CachedCard], count: Int) -> [CachedCard] {
    if !deck.coverCardIds.isEmpty {
        return deck.coverCardIds.compactMap { cardMap[$0] }
    }
    return deck.cards
        .compactMap { dc -> (DeckCard, CachedCard)? in
            guard let card = cardMap[dc.cardId], !card.types.isEmpty else { return nil }
            return (dc, card)
        }
        .sorted { lhs, rhs in
            lhs.0.quantity != rhs.0.quantity
                ? lhs.0.quantity > rhs.0.quantity
                : lhs.1.name < rhs.1.name
        }
        .prefix(count)
        .map(\.1)
}
