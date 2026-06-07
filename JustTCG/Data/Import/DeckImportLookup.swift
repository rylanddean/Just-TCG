import Foundation
import SwiftData

struct DeckImportMatch {
    let entry: DeckImportEntry
    let cardId: String?

    var isMatched: Bool { cardId != nil }
}

struct DeckImportLookup {
    // Maps each entry to a CachedCard by setCode + number.
    // Returns exactly one match when the combination is unique; nil otherwise.
    func resolve(_ entries: [DeckImportEntry], in context: ModelContext) -> [DeckImportMatch] {
        entries.map { entry in
            let setCode = entry.setCode
            let number  = entry.number
            let predicate = #Predicate<CachedCard> { card in
                card.setCode == setCode && card.number == number
            }
            var descriptor = FetchDescriptor<CachedCard>(predicate: predicate)
            descriptor.fetchLimit = 2
            let results = (try? context.fetch(descriptor)) ?? []
            let cardId = results.count == 1 ? results[0].id : nil
            return DeckImportMatch(entry: entry, cardId: cardId)
        }
    }
}
