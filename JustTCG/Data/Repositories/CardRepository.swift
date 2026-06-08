import Foundation
import SwiftData

struct CardPickerSeed {
    let cards: [CachedCard]
    let availableSets: [(code: String, name: String)]
    let availableRarities: [String]
}

final class CardRepository {

    private let context: ModelContext
    private let client: LimitlessTCGClient

    static let lastRefreshKey = "card_cache_last_refreshed"
    private static let staleInterval: TimeInterval = 7 * 24 * 60 * 60

    init(modelContext: ModelContext, client: LimitlessTCGClient = LimitlessTCGClient()) {
        self.context = modelContext
        self.client = client
    }

    // MARK: - Sync

    // Skips if the cache was refreshed within the last 7 days unless force=true.
    // Already-cached cards are preserved if the sync fails mid-way;
    // lastRefreshedAt is only updated on full success.
    func refreshIfStale(force: Bool = false) async throws {
        if !force,
           let last = UserDefaults.standard.object(forKey: Self.lastRefreshKey) as? Date,
           Date().timeIntervalSince(last) < Self.staleInterval {
            print("[CardRepository] cache fresh (last=\(last)), skipping network sync")
            return
        }
        print("[CardRepository] starting network sync (force=\(force))")
        try await syncAllPages()
    }

    private func syncAllPages() async throws {
        var page = 1
        var totalPages = 1

        repeat {
            print("[CardRepository] fetching page \(page)/\(totalPages)")
            let result = try await client.fetchStandardCardPage(page: page)
            print("[CardRepository] page \(page) — \(result.data.count) cards, hasMore=\(result.hasMore), total=\(result.totalCount)")

            if page == 1 {
                let size = result.pageSize > 0 ? result.pageSize : 250
                totalPages = max(1, (result.totalCount + size - 1) / size)
            }

            try upsert(result.data.map { $0.toLimitlessCard() })

            if !result.hasMore { break }
            page += 1
        } while page <= totalPages

        print("[CardRepository] sync complete — \(totalPages) pages")
        UserDefaults.standard.set(Date(), forKey: Self.lastRefreshKey)
    }

    // MARK: - Write

    // Upsert a batch of LimitlessCards. Fetches only the cards in this batch to
    // check for existing entries — one round-trip per batch, not per card.
    func upsert(_ cards: [LimitlessCard]) throws {
        guard !cards.isEmpty else { return }

        let ids = cards.map { $0.id }
        let existing = try context.fetch(
            FetchDescriptor<CachedCard>(
                predicate: #Predicate<CachedCard> { ids.contains($0.id) }
            )
        )
        let existingById = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        for card in cards {
            if let cached = existingById[card.id] {
                cached.update(from: card)
            } else {
                context.insert(CachedCard(from: card))
            }
        }

        try context.save()
    }

    // MARK: - Read

    func fetchAll(standardOnly: Bool = true) throws -> [CachedCard] {
        try context.fetch(
            FetchDescriptor<CachedCard>(
                predicate: standardOnly
                    ? #Predicate<CachedCard> { $0.isStandardLegal }
                    : nil,
                sortBy: [SortDescriptor(\.name)]
            )
        )
    }

    // Fetches a specific set of cards by ID — used by DeckBuilderViewModel to
    // resolve card metadata for the cards already in a deck.
    func fetch(ids: [String]) throws -> [CachedCard] {
        guard !ids.isEmpty else { return [] }
        return try context.fetch(
            FetchDescriptor<CachedCard>(
                predicate: #Predicate<CachedCard> { ids.contains($0.id) }
            )
        )
    }

    // Fetches cards matching a text query, applies all active filter criteria,
    // and orders results by sortOrder.
    func fetch(
        matching query: String = "",
        filterState: CardFilterState = CardFilterState(),
        sortOrder: CardSortOrder = .expansion
    ) throws -> [CachedCard] {
        let results = try fetchFromDB(query: query, sets: Array(filterState.sets), sortOrder: sortOrder)
        if filterState.isEmpty { return results }
        return results.filter { filterState.passes($0) }
    }

    // Returns true if at least one standard-legal card is cached.
    // Uses fetchLimit: 1 to avoid loading the full table.
    func hasAnyStandardCards() throws -> Bool {
        var descriptor = FetchDescriptor<CachedCard>(
            predicate: #Predicate { $0.isStandardLegal }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).isEmpty == false
    }

    // Returns all unique (setCode, setName) pairs sorted by release date (newest first).
    func fetchDistinctSets() throws -> [(code: String, name: String)] {
        let cards = try context.fetch(
            FetchDescriptor<CachedCard>(
                predicate: #Predicate { $0.isStandardLegal },
                sortBy: [SortDescriptor(\.setReleaseDate, order: .reverse)]
            )
        )
        var seen = Set<String>()
        var result: [(code: String, name: String)] = []
        for card in cards where seen.insert(card.setCode).inserted {
            result.append((card.setCode, card.setName))
        }
        return result
    }

    func fetchDistinctRegulationMarks() throws -> [String] {
        let cards = try context.fetch(
            FetchDescriptor<CachedCard>(predicate: #Predicate { $0.isStandardLegal })
        )
        return Array(Set(cards.compactMap(\.regulationMark))).sorted()
    }

    // Returns distinct rarity strings sorted by frequency (most common first).
    func fetchDistinctRarities() throws -> [String] {
        let cards = try context.fetch(
            FetchDescriptor<CachedCard>(predicate: #Predicate { $0.isStandardLegal })
        )
        var freq: [String: Int] = [:]
        for card in cards {
            if let r = card.rarity { freq[r, default: 0] += 1 }
        }
        return freq.keys.sorted { freq[$0, default: 0] > freq[$1, default: 0] }
    }

    // Lightweight meta-only fetch for the filter sheet — derives sets and rarities
    // in one pass without holding onto a full card array.
    func fetchPickerMeta() throws -> (sets: [(code: String, name: String)], rarities: [String]) {
        let cards = try context.fetch(
            FetchDescriptor<CachedCard>(
                predicate: #Predicate { $0.isStandardLegal },
                sortBy: [SortDescriptor(\.setReleaseDate, order: .reverse)]
            )
        )
        var setDate:  [String: Date]   = [:]
        var setNames: [String: String] = [:]
        var rarityFreq: [String: Int]  = [:]
        for card in cards {
            if setDate[card.setCode] == nil {
                setDate[card.setCode]  = card.setReleaseDate
                setNames[card.setCode] = card.setName
            }
            if let r = card.rarity { rarityFreq[r, default: 0] += 1 }
        }
        let sets = setDate.keys
            .sorted { (setDate[$0] ?? .distantPast) > (setDate[$1] ?? .distantPast) }
            .map { (code: $0, name: setNames[$0] ?? "") }
        let rarities = rarityFreq.keys.sorted { rarityFreq[$0, default: 0] > rarityFreq[$1, default: 0] }
        return (sets, rarities)
    }

    // Paginated fetch pushing supertype (from cardGroup), name search, and set filter
    // to the database. No in-memory filtering applied — caller does that if needed.
    func fetchPickerPage(
        offset: Int,
        limit: Int,
        query: String,
        filterState: CardFilterState,
        sortOrder: CardSortOrder
    ) throws -> [CachedCard] {
        var descriptor = buildPickerDescriptor(query: query, filterState: filterState, sortOrder: sortOrder)
        descriptor.fetchOffset = offset
        descriptor.fetchLimit  = limit
        return try context.fetch(descriptor)
    }

    // Fetches all cards matching the DB-pushable portion of filterState.
    // Used for the in-memory-filter path (complex filters or Trainer subtypes).
    func fetchAllPushed(
        query: String,
        filterState: CardFilterState,
        sortOrder: CardSortOrder
    ) throws -> [CachedCard] {
        return try context.fetch(
            buildPickerDescriptor(query: query, filterState: filterState, sortOrder: sortOrder)
        )
    }

    // Single-fetch seed for CardPickerView: returns the card list plus derived
    // sets and rarities so the picker open costs one DB round-trip instead of three.
    func fetchPickerSeed(sortOrder: CardSortOrder = .expansion) throws -> CardPickerSeed {
        let cards = try context.fetch(
            FetchDescriptor<CachedCard>(
                predicate: #Predicate { $0.isStandardLegal },
                sortBy: sortOrder.sortDescriptors
            )
        )

        // Derive sets ordered by release date (newest first) from already-fetched data
        var setDate: [String: Date] = [:]
        var setNames: [String: String] = [:]
        var rarityFreq: [String: Int] = [:]
        for card in cards {
            if setDate[card.setCode] == nil {
                setDate[card.setCode] = card.setReleaseDate
                setNames[card.setCode] = card.setName
            }
            if let r = card.rarity { rarityFreq[r, default: 0] += 1 }
        }

        let sets = setDate.keys
            .sorted { (setDate[$0] ?? .distantPast) > (setDate[$1] ?? .distantPast) }
            .map { (code: $0, name: setNames[$0] ?? "") }
        let rarities = rarityFreq.keys.sorted { rarityFreq[$0, default: 0] > rarityFreq[$1, default: 0] }

        return CardPickerSeed(cards: cards, availableSets: sets, availableRarities: rarities)
    }

    func fetchBasicEnergies() throws -> [CachedCard] {
        // Filter subtypes in memory — #Predicate on a [String] transformable crashes
        // when any row has a null subtypes value (CoreData passes nil to CFStringGetLength).
        let energies = try context.fetch(
            FetchDescriptor<CachedCard>(
                predicate: #Predicate { $0.supertype == "Energy" }
            )
        )
        return energies.filter { $0.subtypes.contains("Basic") }
    }

    // MARK: - Private

    // Builds a FetchDescriptor pushing name search, set filter, and supertype
    // (derived from cardGroup) to SQLite. Complex in-memory filters are NOT applied.
    private func buildPickerDescriptor(
        query: String,
        filterState: CardFilterState,
        sortOrder: CardSortOrder
    ) -> FetchDescriptor<CachedCard> {
        let sort = sortOrder.sortDescriptors
        let sets = Array(filterState.sets)

        // Supertype to push: nil = no restriction, non-nil = exact match
        let supertype: String? = filterState.cardGroup.map { group in
            switch group {
            case .pokemon:                              return "Pokémon"
            case .energy:                              return "Energy"
            case .supporter, .item, .tool, .stadium, .aceSpec: return "Trainer"
            }
        }

        switch (query.isEmpty, sets.isEmpty, supertype) {
        case (true,  true,  nil):
            return FetchDescriptor(predicate: #Predicate {
                $0.isStandardLegal
            }, sortBy: sort)
        case (false, true,  nil):
            return FetchDescriptor(predicate: #Predicate {
                $0.isStandardLegal && $0.name.localizedStandardContains(query)
            }, sortBy: sort)
        case (true,  false, nil):
            return FetchDescriptor(predicate: #Predicate {
                $0.isStandardLegal && sets.contains($0.setCode)
            }, sortBy: sort)
        case (false, false, nil):
            return FetchDescriptor(predicate: #Predicate {
                $0.isStandardLegal && $0.name.localizedStandardContains(query) && sets.contains($0.setCode)
            }, sortBy: sort)
        case (true,  true,  let st?):
            return FetchDescriptor(predicate: #Predicate {
                $0.isStandardLegal && $0.supertype == st
            }, sortBy: sort)
        case (false, true,  let st?):
            return FetchDescriptor(predicate: #Predicate {
                $0.isStandardLegal && $0.name.localizedStandardContains(query) && $0.supertype == st
            }, sortBy: sort)
        case (true,  false, let st?):
            return FetchDescriptor(predicate: #Predicate {
                $0.isStandardLegal && sets.contains($0.setCode) && $0.supertype == st
            }, sortBy: sort)
        case (false, false, let st?):
            return FetchDescriptor(predicate: #Predicate {
                $0.isStandardLegal && $0.name.localizedStandardContains(query)
                    && sets.contains($0.setCode) && $0.supertype == st
            }, sortBy: sort)
        }
    }

    private func fetchFromDB(
        query: String,
        sets: [String],
        sortOrder: CardSortOrder = .expansion
    ) throws -> [CachedCard] {
        let sort = sortOrder.sortDescriptors

        switch (query.isEmpty, sets.isEmpty) {
        case (true, true):
            return try context.fetch(
                FetchDescriptor<CachedCard>(
                    predicate: #Predicate { $0.isStandardLegal },
                    sortBy: sort
                )
            )
        case (false, true):
            return try context.fetch(
                FetchDescriptor<CachedCard>(
                    predicate: #Predicate {
                        $0.isStandardLegal &&
                        $0.name.localizedStandardContains(query)
                    },
                    sortBy: sort
                )
            )
        case (true, false):
            return try context.fetch(
                FetchDescriptor<CachedCard>(
                    predicate: #Predicate {
                        $0.isStandardLegal &&
                        sets.contains($0.setCode)
                    },
                    sortBy: sort
                )
            )
        case (false, false):
            return try context.fetch(
                FetchDescriptor<CachedCard>(
                    predicate: #Predicate {
                        $0.isStandardLegal &&
                        $0.name.localizedStandardContains(query) &&
                        sets.contains($0.setCode)
                    },
                    sortBy: sort
                )
            )
        }
    }
}
