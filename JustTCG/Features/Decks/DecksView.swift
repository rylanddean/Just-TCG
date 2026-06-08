import SwiftUI
import SwiftData

struct DecksView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Deck.updatedAt, order: .reverse) private var decks: [Deck]

    @State private var deckToDelete: Deck? = nil
    @State private var deckToRename: Deck? = nil
    @State private var renameText = ""
    @State private var showNewDeckSheet = false
    @State private var showImportSheet = false

    var body: some View {
        NavigationStack {
            Group {
                if decks.isEmpty {
                    emptyState
                } else {
                    deckList
                }
            }
            .navigationTitle("Decks")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button { showImportSheet = true } label: {
                        Image(systemName: "arrow.down.doc")
                    }
                    Button { showNewDeckSheet = true } label: {
                        Image(systemName: "plus")
                    }
                }
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
        }
    }

    // MARK: - Sub-views

    private var deckList: some View {
        List {
            ForEach(decks) { deck in
                NavigationLink(destination: DeckDetailView(mode: .edit(deck))) {
                    DeckRowView(deck: deck)
                }
                .swipeActions(edge: .leading) {
                    Button {
                        renameText = deck.name
                        deckToRename = deck
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    .tint(.orange)
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

    private var cardCount: Int {
        deck.cards.reduce(0) { $0 + $1.quantity }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(deck.name)
                .font(.headline)
            HStack {
                Text("\(cardCount)/60")
                    .foregroundStyle(cardCount == 60 ? .primary : .secondary)
                Spacer()
                Text(deck.updatedAt, format: .relative(presentation: .named))
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
        }
        .padding(.vertical, 4)
    }
}
