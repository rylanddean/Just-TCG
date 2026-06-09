import Foundation

struct ArchetypePrimaryCardResolver {
    func resolve(archetype: String, from cards: [CachedCard]) -> CachedCard? {
        let primaryName = archetype
            .split(separator: "/", maxSplits: 1)
            .first
            .map { $0.trimmingCharacters(in: .whitespaces) }
            ?? archetype.trimmingCharacters(in: .whitespaces)

        let pokemonCards = cards.filter { $0.supertype == "Pokémon" }
        let normalised = primaryName.lowercased()

        if let exact = pokemonCards.first(where: { $0.name.lowercased() == normalised }) {
            return exact
        }

        return pokemonCards.first {
            $0.name.lowercased().hasPrefix(normalised) ||
            normalised.hasPrefix($0.name.lowercased())
        }
    }
}
