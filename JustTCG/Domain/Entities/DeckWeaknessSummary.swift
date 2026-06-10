import Foundation

/// Aggregates the printed `weaknessType` values from the Pokémon cards present
/// in a deck. Reads directly from the authoritative `CachedCard.weaknessType`
/// field (populated from the bundled JSON pipeline) rather than the lossy
/// `DeckCardEntry` projection used elsewhere.
enum DeckWeaknessSummary {
    /// Returns the sorted, deduplicated set of printed weakness types across
    /// the supplied Pokémon cards. The caller is responsible for filtering to
    /// Pokémon-supertype cards that actually have at least one copy in the deck.
    static func weaknessTypes(in pokemonCards: [CachedCard]) -> [String] {
        var seen: Set<String> = []
        for card in pokemonCards {
            guard let type = card.weaknessType, !type.isEmpty else { continue }
            seen.insert(type)
        }
        return seen.sorted()
    }
}
