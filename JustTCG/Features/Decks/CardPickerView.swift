import SwiftUI
import SwiftData

struct CardPickerView: View {
    let deck: Deck

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var cards: [CachedCard] = []
    @State private var availableSets: [(code: String, name: String)] = []

    @State private var searchText = ""
    @State private var filterState = CardFilterState()
    @State private var showFilterSheet = false

    @State private var cardForDetail: CachedCard? = nil
    @State private var searchTask: Task<Void, Never>? = nil

    var body: some View {
        NavigationStack {
            Group {
                if cards.isEmpty && (!searchText.isEmpty || !filterState.isEmpty) {
                    noResultsState
                } else {
                    pickerList
                }
            }
            .navigationTitle("Add Cards")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search cards")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    filterButton
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showFilterSheet) {
                CardFilterView(filterState: $filterState, availableSets: availableSets)
            }
            .sheet(item: $cardForDetail) { card in
                NavigationStack {
                    CardDetailView(card: card, onAddToDeck: {
                        addCard(card)
                        cardForDetail = nil
                    })
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { cardForDetail = nil }
                        }
                    }
                }
            }
        }
        .task { await loadInitial() }
        .onChange(of: searchText) { _, _ in scheduleSearch() }
        .onChange(of: filterState) { _, _ in Task { await loadCards() } }
    }

    // MARK: - Sub-views

    private var pickerList: some View {
        List {
            if !filterState.isEmpty {
                filterChipsRow
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparator(.hidden)
            }
            ForEach(cards) { card in
                CardPickerRow(
                    card: card,
                    deckQuantity: deckQuantity(for: card),
                    isAtMax: isAtMax(card)
                ) {
                    addCard(card)
                } onLongPress: {
                    cardForDetail = card
                }
            }
        }
        .listStyle(.plain)
    }

    private var noResultsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No Results")
                .font(.title3.bold())
            Text("Try adjusting your search or filters.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !filterState.isEmpty {
                Button("Clear Filters") { filterState = CardFilterState() }
                    .buttonStyle(.bordered)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var filterButton: some View {
        Button { showFilterSheet = true } label: {
            Image(systemName: filterState.isEmpty
                  ? "line.3.horizontal.decrease.circle"
                  : "line.3.horizontal.decrease.circle.fill")
        }
    }

    private var filterChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(filterState.types).sorted(), id: \.self) { type in
                    FilterChip(label: type) { filterState.types.remove(type) }
                }
                ForEach(Array(filterState.subtypes).sorted(), id: \.self) { subtype in
                    FilterChip(label: subtype) { filterState.subtypes.remove(subtype) }
                }
                ForEach(Array(filterState.sets).sorted(), id: \.self) { setCode in
                    let name = availableSets.first(where: { $0.code == setCode })?.name ?? setCode
                    FilterChip(label: name) { filterState.sets.remove(setCode) }
                }
                Button("Clear all") { filterState = CardFilterState() }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Data

    private func loadInitial() async {
        let repo = CardRepository(modelContext: context)
        availableSets = (try? repo.fetchDistinctSets()) ?? []
        await loadCards()
    }

    private func loadCards() async {
        let repo = CardRepository(modelContext: context)
        cards = (try? repo.fetch(
            matching: searchText,
            types: Array(filterState.types),
            subtypes: Array(filterState.subtypes),
            sets: Array(filterState.sets)
        )) ?? cards
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await loadCards()
        }
    }

    // MARK: - Deck helpers

    private func deckQuantity(for card: CachedCard) -> Int {
        deck.cards.first(where: { $0.cardId == card.id })?.quantity ?? 0
    }

    private func isAtMax(_ card: CachedCard) -> Bool {
        let qty = deckQuantity(for: card)
        let totalCount = deck.cards.reduce(0) { $0 + $1.quantity }
        guard totalCount < 60 else { return true }
        let isBasicEnergy = card.subtypes.contains("Basic Energy")
        return !isBasicEnergy && qty >= 4
    }

    private func addCard(_ card: CachedCard) {
        let isBasicEnergy = card.subtypes.contains("Basic Energy")
        DeckRepository(modelContext: context)
            .addCard(cardId: card.id, to: deck, isBasicEnergy: isBasicEnergy)
    }
}

// MARK: - Picker row

private struct CardPickerRow: View {
    let card: CachedCard
    let deckQuantity: Int
    let isAtMax: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: card.imageURL)) { phase in
                switch phase {
                case .success(let img):
                    img.resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                default:
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))
                        .aspectRatio(7/10, contentMode: .fit)
                }
            }
            .frame(width: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(card.name)
                    .font(.body)
                Text("\(card.setName) · #\(card.number)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if deckQuantity > 0 {
                Text("\(deckQuantity) in deck")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .opacity(isAtMax ? 0.4 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture { if !isAtMax { onTap() } }
        .onLongPressGesture { onLongPress() }
        .padding(.vertical, 4)
    }
}

// MARK: - Filter chip (shared with CardsView)

private struct FilterChip: View {
    let label: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption.weight(.medium))
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.12))
        .foregroundStyle(Color.accentColor)
        .clipShape(Capsule())
    }
}
