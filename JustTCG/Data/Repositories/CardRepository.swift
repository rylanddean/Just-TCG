import Foundation
import SwiftData

final class CardRepository {

    private let context: ModelContext
    private let client: LimitlessTCGClient

    private static let lastRefreshKey = "card_cache_last_refreshed"
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
            return
        }
        try await syncAllPages()
    }

    private func syncAllPages() async throws {
        var page = 1
        var totalPages = 1

        repeat {
            let result = try await client.fetchStandardCardPage(page: page)

            if page == 1 {
                let size = result.pageSize > 0 ? result.pageSize : 250
                totalPages = max(1, (result.totalCount + size - 1) / size)
            }

            try upsert(result.data.map { $0.toLimitlessCard() })

            if !result.hasMore { break }
            page += 1
        } while page <= totalPages

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

    // Filters cards by name query, energy type(s), subtype(s), and set code(s).
    // Name and set filters run at the DB level; type/subtype filtering runs
    // in-memory (SwiftData can't query stored [String] arrays efficiently).
    func fetch(
        matching query: String = "",
        types: [String] = [],
        subtypes: [String] = [],
        sets: [String] = []
    ) throws -> [CachedCard] {
        var results = try fetchFromDB(query: query, sets: sets)

        if !types.isEmpty {
            let typeSet = Set(types)
            results = results.filter { !Set($0.types).isDisjoint(with: typeSet) }
        }
        if !subtypes.isEmpty {
            let subtypeSet = Set(subtypes)
            results = results.filter { !Set($0.subtypes).isDisjoint(with: subtypeSet) }
        }
        return results
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

    // Returns all unique (setCode, setName) pairs sorted alphabetically by name.
    func fetchDistinctSets() throws -> [(code: String, name: String)] {
        let cards = try context.fetch(
            FetchDescriptor<CachedCard>(predicate: #Predicate { $0.isStandardLegal })
        )
        var seen = Set<String>()
        var result: [(code: String, name: String)] = []
        for card in cards where seen.insert(card.setCode).inserted {
            result.append((card.setCode, card.setName))
        }
        return result.sorted { $0.name < $1.name }
    }

    // MARK: - Private

    private func fetchFromDB(query: String, sets: [String]) throws -> [CachedCard] {
        let sort = [SortDescriptor<CachedCard>(\.name)]

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
