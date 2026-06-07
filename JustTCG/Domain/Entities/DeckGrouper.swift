import Foundation

struct DeckGrouper {
    private static let trainerSubtypes: Set<String> = ["Supporter", "Item", "Stadium", "Tool"]

    struct Groups {
        let pokemon: [DeckCard]
        let trainer: [DeckCard]
        let energy: [DeckCard]
    }

    static func group(_ deckCards: [DeckCard], cardMap: [String: CachedCard]) -> Groups {
        func sorted(_ cards: [DeckCard]) -> [DeckCard] {
            cards.sorted { (cardMap[$0.cardId]?.name ?? $0.cardId) < (cardMap[$1.cardId]?.name ?? $1.cardId) }
        }

        let pokemon = sorted(deckCards.filter {
            guard let c = cardMap[$0.cardId] else { return false }
            return !c.types.isEmpty
        })
        let trainer = sorted(deckCards.filter {
            guard let c = cardMap[$0.cardId] else { return false }
            return c.types.isEmpty && !Set(c.subtypes).isDisjoint(with: trainerSubtypes)
        })
        let energy = sorted(deckCards.filter {
            guard let c = cardMap[$0.cardId] else { return false }
            return c.types.isEmpty && Set(c.subtypes).isDisjoint(with: trainerSubtypes)
        })

        return Groups(pokemon: pokemon, trainer: trainer, energy: energy)
    }
}
