import Foundation

struct DeckValidator {
    static func validate(_ deck: Deck, cards: [CachedCard]) -> [DeckValidationError] {
        var errors: [DeckValidationError] = []
        let cardMap = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })

        // Error: total card count ≠ 60
        let total = deck.cards.reduce(0) { $0 + $1.quantity }
        if total != 60 {
            errors.append(.tooManyCards(count: total))
        }

        var hasBasicPokemon = false
        for deckCard in deck.cards {
            guard let card = cardMap[deckCard.cardId] else { continue }

            let isBasicEnergy = card.subtypes.contains("Basic Energy")

            // Error: > 4 copies of a named card (excluding Basic Energy)
            if !isBasicEnergy && deckCard.quantity > 4 {
                errors.append(.duplicateCard(name: card.name, count: deckCard.quantity))
            }

            // Error: card not Standard-legal
            if !card.isStandardLegal {
                errors.append(.illegalCard(name: card.name))
            }

            // Pokémon cards have non-empty types; Basic stage adds "Basic" subtype
            if !card.types.isEmpty && card.subtypes.contains("Basic") {
                hasBasicPokemon = true
            }
        }

        // Warning: no Basic Pokémon (skip for an entirely empty deck — other errors cover it)
        if !hasBasicPokemon && !deck.cards.isEmpty {
            errors.append(.noBasicPokemon)
        }

        return errors
    }
}
