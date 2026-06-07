import Foundation
import SwiftData

final class CardRepository {

    private let context: ModelContext

    init(modelContext: ModelContext) {
        self.context = modelContext
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

    // Filters cards by name query, energy type(s), and set code(s).
    // Name and set filters run at the database level; type filtering (on a stored
    // String array) runs in-memory after the DB fetch.
    func fetch(matching query: String = "", types: [String] = [], sets: [String] = []) throws -> [CachedCard] {
        let dbResults = try fetchFromDB(query: query, sets: sets)

        guard !types.isEmpty else { return dbResults }
        let typeSet = Set(types)
        return dbResults.filter { !Set($0.types).isDisjoint(with: typeSet) }
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
