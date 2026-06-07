import Foundation

struct DeckExporter {
    static func export(_ deck: Deck, cards: [CachedCard]) -> String {
        let cardMap = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })
        let groups = DeckGrouper.group(deck.cards, cardMap: cardMap)

        var output = ""

        let pokemonCount = groups.pokemon.reduce(0) { $0 + $1.quantity }
        let trainerCount = groups.trainer.reduce(0) { $0 + $1.quantity }
        let energyCount  = groups.energy.reduce(0)  { $0 + $1.quantity }
        let totalCount   = pokemonCount + trainerCount + energyCount

        func appendSection(_ label: String, count: Int, deckCards: [DeckCard]) {
            guard !deckCards.isEmpty else { return }
            output += "\(label): \(count)\n"
            for dc in deckCards {
                if let card = cardMap[dc.cardId] {
                    output += "\(dc.quantity) \(card.name) \(card.setCode.uppercased()) \(card.number)\n"
                }
            }
            output += "\n"
        }

        appendSection("Pokémon", count: pokemonCount, deckCards: groups.pokemon)
        appendSection("Trainer", count: trainerCount, deckCards: groups.trainer)
        appendSection("Energy",  count: energyCount,  deckCards: groups.energy)

        output += "Total Cards: \(totalCount)"
        return output
    }
}
