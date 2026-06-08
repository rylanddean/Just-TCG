import SwiftUI
import SwiftData

struct CardsView: View {
    @Environment(\.modelContext) private var context

    @State private var cards: [CachedCard] = []
    @State private var availableSets: [(code: String, name: String)] = []
    @State private var availableRegulationMarks: [String] = []
    @State private var availableRarities: [String] = []
    @State private var hasCards = false

    @State private var searchText = ""
    @State private var filterState = CardFilterState()
    @State private var showFilterSheet = false
    @State private var sortOrder: CardSortOrder = .expansion

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
                        sortMenu
                    }
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
                    CardFilterView(
                        filterState: $filterState,
                        availableSets: availableSets,
                        availableRegulationMarks: availableRegulationMarks,
                        availableRarities: availableRarities
                    )
                }
        }
        .task { await initialLoad() }
        .onChange(of: searchText) { _, _ in scheduleSearch() }
        .onChange(of: filterState) { _, _ in Task { await loadCards() } }
        .onChange(of: sortOrder) { _, _ in Task { await loadCards() } }
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
                groupChipStrip
                Divider()
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

    private var groupChipStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                groupChip(nil, label: "All")
                ForEach(CardGroup.allCases) { group in
                    groupChip(group, label: group.rawValue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func groupChip(_ group: CardGroup?, label: String) -> some View {
        let isSelected = filterState.cardGroup == group
        return Text(label)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color(.secondarySystemFill))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
            .onTapGesture {
                filterState.cardGroup = isSelected ? nil : group
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

    private func initialLoad() async {
        let seededKey = UserDefaults.standard.bool(forKey: BundledCardSeeder.seededKey)
        let lastRefresh = UserDefaults.standard.object(forKey: CardRepository.lastRefreshKey) as? Date
        print("[CardsView] initialLoad start — seededKey=\(seededKey) lastRefresh=\(lastRefresh?.description ?? "nil")")

        await BundledCardSeeder.seedIfNeeded(context: context)
        print("[CardsView] seedIfNeeded complete")

        let repo = CardRepository(modelContext: context)
        do {
            hasCards = try repo.hasAnyStandardCards()
            print("[CardsView] post-seed hasCards=\(hasCards)")
        } catch {
            print("[CardsView] hasAnyStandardCards error: \(error)")
        }

        if hasCards {
            await loadCards()
            loadFilterMetadata(repo: repo)
        }

        isSyncing = true
        syncError = nil
        print("[CardsView] starting refreshIfStale")
        do {
            try await repo.refreshIfStale(force: false)
            print("[CardsView] refreshIfStale complete")
        } catch {
            print("[CardsView] refreshIfStale error: \(error)")
            syncError = error.localizedDescription
        }
        isSyncing = false

        do {
            hasCards = try repo.hasAnyStandardCards()
            print("[CardsView] post-sync hasCards=\(hasCards) cards.count=\(cards.count)")
        } catch {
            print("[CardsView] post-sync hasAnyStandardCards error: \(error)")
        }
        await loadCards()
        loadFilterMetadata(repo: repo)
        print("[CardsView] initialLoad done — cards.count=\(cards.count)")
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
        loadFilterMetadata(repo: repo)
    }

    private func loadFilterMetadata(repo: CardRepository) {
        availableSets = (try? repo.fetchDistinctSets()) ?? []
        availableRegulationMarks = (try? repo.fetchDistinctRegulationMarks()) ?? []
        availableRarities = (try? repo.fetchDistinctRarities()) ?? []
    }

    private func loadCards() async {
        let repo = CardRepository(modelContext: context)
        cards = (try? repo.fetch(matching: searchText, filterState: filterState, sortOrder: sortOrder)) ?? cards
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
