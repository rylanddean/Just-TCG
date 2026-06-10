import Foundation
import SwiftData

struct DeckImportMatch: Identifiable {
    let entry: DeckImportEntry
    var cardId: String?
    /// Small thumbnail URL — present whenever the card was resolved.
    var imageURL: String?
    /// High-res image URL for the full-screen preview.
    var largeImageURL: String?

    var id: String { entry.name + entry.setCode + entry.number }
    var isMatched: Bool { cardId != nil }
}

struct DeckImportLookup {

    // PTCGL energy symbol → canonical type word
    private static let symbolToType: [String: String] = [
        "{G}": "Grass",    "{R}": "Fire",      "{W}": "Water",
        "{L}": "Lightning", "{P}": "Psychic",  "{F}": "Fighting",
        "{D}": "Darkness", "{M}": "Metal",
    ]

    // Maps each entry to a CachedCard.
    // Primary path: exact setCode + number match.
    // Fallback path: Basic Energy entries resolved by energy type regardless of set.
    func resolve(_ entries: [DeckImportEntry], in context: ModelContext) -> [DeckImportMatch] {
        let basicEnergyCards = Self.loadBasicEnergyCards(in: context)
        return entries.map { entry in
            // Primary: exact set/number match
            let setCode = entry.setCode
            let number  = entry.number
            var descriptor = FetchDescriptor<CachedCard>(
                predicate: #Predicate<CachedCard> { $0.setCode == setCode && $0.number == number }
            )
            descriptor.fetchLimit = 2
            let exact = (try? context.fetch(descriptor)) ?? []
            if exact.count == 1 {
                let card = exact[0]
                return DeckImportMatch(entry: entry, cardId: card.id,
                                       imageURL: card.imageURL, largeImageURL: card.largeImageURL)
            }

            // Fallback: Basic Energy resolved by energy type
            if let energyType = Self.basicEnergyType(from: entry.name),
               let card = basicEnergyCards.first(where: { $0.name.contains(energyType) }) {
                return DeckImportMatch(entry: entry, cardId: card.id,
                                       imageURL: card.imageURL, largeImageURL: card.largeImageURL)
            }

            return DeckImportMatch(entry: entry, cardId: nil)
        }
    }

    // Loads all Basic Energy cards once for the whole batch.
    // SVE prints are placed first since they're the canonical Basic Energy.
    private static func loadBasicEnergyCards(in context: ModelContext) -> [CachedCard] {
        let descriptor = FetchDescriptor<CachedCard>(
            predicate: #Predicate { $0.supertype == "Energy" }
        )
        let all = (try? context.fetch(descriptor)) ?? []
        return all
            .filter { $0.isBasicEnergy }
            .sorted { $0.setCode == "SVE" && $1.setCode != "SVE" }
    }

    // Extracts the energy type word from a Basic Energy entry name, or returns nil.
    //   "Basic {D} Energy" → "Darkness"
    //   "Darkness Energy"  → "Darkness"
    //   "Basic Fire Energy" → "Fire"
    private static func basicEnergyType(from name: String) -> String? {
        for (symbol, type) in symbolToType where name.contains(symbol) {
            return type
        }
        let knownTypes = Set(symbolToType.values)
        let cleaned = name
            .replacingOccurrences(of: "Basic", with: "")
            .replacingOccurrences(of: "Energy", with: "")
            .trimmingCharacters(in: .whitespaces)
        return knownTypes.contains(cleaned) ? cleaned : nil
    }
}
