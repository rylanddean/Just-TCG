import SwiftUI
import SwiftData

struct CardsView: View {
    @Environment(\.modelContext) private var context

    @State private var cards: [CachedCard] = []
    @State private var availableSets: [(code: String, name: String)] = []
    @State private var hasCards = false

    @State private var searchText = ""
    @State private var filterState = CardFilterState()
    @State private var showFilterSheet = false

    @State private var isSyncing = false
    @State private var syncError: String? = nil

    @State private var searchTask: Task<Void, Never>? = nil

    private let columns = [
        GridItem(.flexible(minimum: 100)),
        GridItem(.flexible(minimum: 100)),
        GridItem(.flexible(minimum: 100)),
    ]

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Cards")
                .searchable(text: $searchText, prompt: "Search cards")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        filterButton
                    }
                    if isSyncing && hasCards {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            ProgressView().scaleEffect(0.8)
                        }
                    }
                }
                .sheet(isPresented: $showFilterSheet) {
                    CardFilterView(filterState: $filterState, availableSets: availableSets)
                }
        }
        .task { await initialLoad() }
        .onChange(of: searchText) { _, _ in scheduleSearch() }
        .onChange(of: filterState) { _, _ in Task { await loadCards() } }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isSyncing && !hasCards {
            skeletonGrid
        } else if !hasCards && syncError != nil {
            offlineEmptyState
        } else if !hasCards {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                if !filterState.isEmpty {
                    filterChipsRow
                    Divider()
                }
                if cards.isEmpty {
                    noResultsState
                } else {
                    cardGrid
                }
            }
        }
    }

    private var cardGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(cards) { card in
                    NavigationLink(destination: CardDetailView(card: card)) {
                        CardThumbnailView(card: card)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
        }
        .refreshable { await forceRefresh() }
    }

    private var skeletonGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0..<30, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.15))
                        .aspectRatio(7/10, contentMode: .fit)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
        }
    }

    private var offlineEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Connection")
                .font(.title2.bold())
            Text("Cards will load once you connect to the internet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Try Again") {
                Task { await forceRefresh() }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    // MARK: - Filter UI

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

    // MARK: - Data loading

    private func initialLoad() async {
        let repo = CardRepository(modelContext: context)
        hasCards = (try? repo.hasAnyStandardCards()) ?? false
        if hasCards {
            await loadCards()
            availableSets = (try? repo.fetchDistinctSets()) ?? []
        }

        isSyncing = true
        syncError = nil
        do {
            try await repo.refreshIfStale(force: false)
        } catch {
            syncError = error.localizedDescription
        }
        isSyncing = false

        hasCards = (try? repo.hasAnyStandardCards()) ?? false
        await loadCards()
        availableSets = (try? repo.fetchDistinctSets()) ?? []
    }

    private func forceRefresh() async {
        isSyncing = true
        syncError = nil
        let repo = CardRepository(modelContext: context)
        do {
            try await repo.refreshIfStale(force: true)
        } catch {
            syncError = error.localizedDescription
        }
        isSyncing = false
        hasCards = (try? repo.hasAnyStandardCards()) ?? false
        await loadCards()
        availableSets = (try? repo.fetchDistinctSets()) ?? []
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
}

// MARK: - Filter chip

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
