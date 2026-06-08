import Foundation

struct DeckGrouper {

    struct TrainerGroups {
        let supporter: [DeckCard]
        let item:      [DeckCard]
        let tool:      [DeckCard]
        let stadium:   [DeckCard]
        let aceSpec:   [DeckCard]
    }

    struct Groups {
        let pokemon:       [DeckCard]
        let trainerGroups: TrainerGroups
        let energy:        [DeckCard]
    }

    static func group(_ deckCards: [DeckCard], cardMap: [String: CachedCard]) -> Groups {
        func sorted(_ cards: [DeckCard]) -> [DeckCard] {
            cards.sorted { (cardMap[$0.cardId]?.name ?? $0.cardId) < (cardMap[$1.cardId]?.name ?? $1.cardId) }
        }

        var pokemon:   [DeckCard] = []
        var supporter: [DeckCard] = []
        var item:      [DeckCard] = []
        var tool:      [DeckCard] = []
        var stadium:   [DeckCard] = []
        var aceSpec:   [DeckCard] = []
        var energy:    [DeckCard] = []

        for dc in deckCards {
            guard let c = cardMap[dc.cardId] else { continue }
            if !c.types.isEmpty {
                pokemon.append(dc)
            } else {
                let subs = Set(c.subtypes)
                if subs.contains("Supporter")        { supporter.append(dc) }
                else if subs.contains("Item")         { item.append(dc) }
                else if subs.contains("Pokémon Tool") { tool.append(dc) }
                else if subs.contains("Stadium")      { stadium.append(dc) }
                else if subs.contains("ACE SPEC")     { aceSpec.append(dc) }
                else                                  { energy.append(dc) }
            }
        }

        return Groups(
            pokemon: sorted(pokemon),
            trainerGroups: TrainerGroups(
                supporter: sorted(supporter),
                item:      sorted(item),
                tool:      sorted(tool),
                stadium:   sorted(stadium),
                aceSpec:   sorted(aceSpec)
            ),
            energy: sorted(energy)
        )
    }
}
