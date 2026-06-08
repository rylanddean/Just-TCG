import SwiftUI
import SwiftData

struct CardPickerView: View {
    @Bindable var deck: Deck

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var availableSets: [(code: String, name: String)] = []
    @State private var availableRarities: [String] = []

    @State private var searchText = ""
    @State private var filterState: CardFilterState
    @State private var showFilterSheet = false
    @State private var sortOrder: CardSortOrder = .expansion

    init(deck: Deck, initialFilter: CardFilterState = CardFilterState()) {
        _deck = Bindable(wrappedValue: deck)
        _filterState = State(initialValue: initialFilter)
    }

    // MARK: - Pagination state

    @State private var cards: [CachedCard] = []
    @State private var hasMore = false
    @State private var dbOffset = 0
    @State private var filteredPool: [CachedCard] = []

    @State private var isLoading = false
    @State private var loadTask: Task<Void, Never>? = nil
    @State private var cardForDetail: CachedCard? = nil

    private let pageSize = 75

    // DB pagination is safe when all active filters can be pushed to the predicate.
    private var canUseDBPagination: Bool {
        !filterState.hasComplexFilters && !filterState.groupNeedsInMemoryCheck
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if cards.isEmpty && (!searchText.isEmpty || !filterState.isEmpty) {
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
                    sortMenu
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showFilterSheet) {
                CardFilterView(
                    filterState: $filterState,
                    availableSets: availableSets,
                    availableRarities: availableRarities,
                    hideRegulationMark: true
                )
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
        .onChange(of: searchText)    { _, _ in scheduleReload() }
        .onChange(of: filterState)   { _, _ in reload() }
        .onChange(of: sortOrder)     { _, _ in reload() }
    }

    // MARK: - Sub-views

    private var pickerList: some View {
        List {
            ForEach(cards) { card in
                CardPickerRow(
                    card: card,
                    deckQuantity: deckQuantity(for: card),
                    isAtMax: isAtMax(card)
                ) {
                    addCard(card)
                } onDecrement: {
                    decrementCard(card)
                } onLongPress: {
                    cardForDetail = card
                }
            }

            if hasMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                    .onAppear { appendNextPage() }
            }
        }
        .listStyle(.plain)
        .safeAreaInset(edge: .top, spacing: 0) {
            if !filterState.isEmpty {
                filterChipsRow
                    .background(.bar)
            }
        }
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

    private var sortMenu: some View {
        Menu {
            ForEach(CardSortOrder.allCases) { order in
                Button {
                    sortOrder = order
                } label: {
                    Label {
                        Text(order.menuLabel)
                    } icon: {
                        if sortOrder == order { Image(systemName: "checkmark") }
                    }
                }
            }
        } label: {
            Image(systemName: sortOrder == .expansion
                  ? "arrow.up.arrow.down"
                  : "arrow.up.arrow.down.circle.fill")
        }
        .accessibilityLabel("Sort cards")
        .accessibilityValue(sortOrder.menuLabel)
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
                ForEach(filterState.activeChips) { chip in
                    FilterChip(label: chip.label) { filterState.clearChip(id: chip.id) }
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

    // MARK: - Data loading

    private func loadInitial() async {
        isLoading = true
        await Task.yield()
        let repo = CardRepository(modelContext: context)
        if let meta = try? repo.fetchPickerMeta() {
            availableSets    = meta.sets
            availableRarities = meta.rarities
        }
        await performLoad(reset: true)
        isLoading = false
    }

    private func reload() {
        loadTask?.cancel()
        loadTask = Task { await performLoad(reset: true) }
    }

    private func scheduleReload() {
        loadTask?.cancel()
        loadTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await performLoad(reset: true)
        }
    }

    private func appendNextPage() {
        guard hasMore, loadTask == nil || loadTask!.isCancelled else { return }
        loadTask = Task { await performLoad(reset: false) }
    }

    private func performLoad(reset: Bool) async {
        guard !Task.isCancelled else { return }

        let repo = CardRepository(modelContext: context)

        if reset {
            cards        = []
            dbOffset     = 0
            filteredPool = []
        }

        if canUseDBPagination {
            // DB-level pagination — no in-memory filtering required.
            let page = (try? repo.fetchPickerPage(
                offset: dbOffset,
                limit: pageSize,
                query: searchText,
                filterState: filterState,
                sortOrder: sortOrder
            )) ?? []
            guard !Task.isCancelled else { return }
            cards.append(contentsOf: page)
            dbOffset = cards.count
            hasMore  = page.count == pageSize
        } else {
            // Some filters need in-memory evaluation. Fetch the DB-pushable subset
            // (supertype + name + sets) once, filter in memory, then serve in pages.
            if reset {
                let fromDB = (try? repo.fetchAllPushed(
                    query: searchText,
                    filterState: filterState,
                    sortOrder: sortOrder
                )) ?? []
                guard !Task.isCancelled else { return }
                filteredPool = fromDB.filter { filterState.passes($0) }
            }
            let batch = Array(filteredPool.dropFirst(cards.count).prefix(pageSize))
            guard !Task.isCancelled else { return }
            cards.append(contentsOf: batch)
            hasMore = cards.count < filteredPool.count
        }

        loadTask = nil
    }

    // MARK: - Deck helpers

    private func deckQuantity(for card: CachedCard) -> Int {
        deck.cards.first(where: { $0.cardId == card.id })?.quantity ?? 0
    }

    private func isAtMax(_ card: CachedCard) -> Bool {
        let qty = deckQuantity(for: card)
        let totalCount = deck.cards.reduce(0) { $0 + $1.quantity }
        guard totalCount < 60 else { return true }
        return !card.isBasicEnergy && qty >= 4
    }

    private func addCard(_ card: CachedCard) {
        DeckRepository(modelContext: context)
            .addCard(cardId: card.id, to: deck, isBasicEnergy: card.isBasicEnergy, cardName: card.name)
    }

    private func decrementCard(_ card: CachedCard) {
        let qty = deckQuantity(for: card)
        let repo = DeckRepository(modelContext: context)
        if qty <= 1 {
            repo.removeCard(cardId: card.id, from: deck, cardName: card.name)
        } else {
            repo.setQuantity(qty - 1, cardId: card.id, in: deck, cardName: card.name)
        }
    }
}

// MARK: - Picker row

private struct CardPickerRow: View {
    let card: CachedCard
    let deckQuantity: Int
    let isAtMax: Bool
    let onAdd: () -> Void
    let onDecrement: () -> Void
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
                HStack(spacing: 6) {
                    Button {
                        onDecrement()
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.title3)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)

                    Text("\(deckQuantity)")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Color.accentColor)
                        .frame(minWidth: 14, alignment: .center)

                    Button {
                        onAdd()
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.title3)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(isAtMax ? Color.secondary : Color.accentColor)
                    .disabled(isAtMax)
                }
            }
        }
        .opacity(deckQuantity == 0 && isAtMax ? 0.4 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture {
            if deckQuantity == 0 && !isAtMax { onAdd() }
        }
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
