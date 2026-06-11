import Foundation

struct ArchetypePrimaryCardResolver {
    static func resolveAll(names: [String], from cards: [CachedCard]) -> [CachedCard] {
        let resolver = ArchetypePrimaryCardResolver()
        var seen = Set<String>()
        var result: [CachedCard] = []
        for name in names {
            if let card = resolver.resolve(archetype: name, from: cards), !seen.contains(card.id) {
                seen.insert(card.id)
                result.append(card)
            }
        }
        return result
    }

    /// Returns up to `maxCount` cards for the archetype string.
    ///
    /// Handles both slash-separated names ("Charizard ex / Pidgeot ex") and
    /// space-separated names ("Charizard Pidgeot", "Iron Hands Raichu ex") via
    /// a greedy longest-match scan so multi-word names like "Iron Hands ex" are
    /// found correctly before moving on to the next Pokémon.
    func resolveMultiple(archetype: String, from cards: [CachedCard], maxCount: Int = 2) -> [CachedCard] {
        let pokemonCards = cards.filter { $0.supertype == "Pokémon" }

        if archetype.contains("/") {
            // Slash-separated: resolve each segment in order
            var seen = Set<String>()
            var result: [CachedCard] = []
            for segment in archetype.split(separator: "/").prefix(maxCount) {
                let name = segment.trimmingCharacters(in: .whitespaces)
                if let card = findCard(named: name, in: pokemonCards), !seen.contains(card.id) {
                    seen.insert(card.id)
                    result.append(card)
                }
            }
            return result
        } else {
            // No slash: greedy longest-match word scan
            return greedyScan(archetype: archetype, pokemonCards: pokemonCards, maxCount: maxCount)
        }
    }

    // MARK: - Private helpers

    private func findCard(named name: String, in pokemonCards: [CachedCard]) -> CachedCard? {
        let normalised = name.lowercased()
        let preferred = pokemonCards.filter { $0.imageURL.contains("pokemontcg.io") }
        let pool = preferred.isEmpty ? pokemonCards : preferred
        return pool.first(where: { $0.name.lowercased() == normalised })
            ?? pool.first(where: {
                $0.name.lowercased().hasPrefix(normalised) ||
                normalised.hasPrefix($0.name.lowercased())
            })
    }

    /// Scans `archetype` word-by-word, greedily consuming the longest contiguous
    /// word run that matches a Pokémon name, then repeating from the next word.
    private func greedyScan(archetype: String, pokemonCards: [CachedCard], maxCount: Int) -> [CachedCard] {
        let words = archetype.split(separator: " ").map(String.init)
        var result: [CachedCard] = []
        var seen = Set<String>()
        var i = 0

        while i < words.count && result.count < maxCount {
            var bestCard: CachedCard?
            var bestEnd = i

            // Try every window from (i..<i+1) up to (i..<words.count)
            for j in (i + 1)...words.count {
                let candidate = words[i..<j].joined(separator: " ")
                if let card = findCard(named: candidate, in: pokemonCards), !seen.contains(card.id) {
                    // Keep going — a longer window might give a more precise match
                    bestCard = card
                    bestEnd = j
                }
            }

            if let card = bestCard {
                seen.insert(card.id)
                result.append(card)
                i = bestEnd
            } else {
                i += 1 // no match starting here; skip this word
            }
        }

        return result
    }

    func resolve(archetype: String, from cards: [CachedCard]) -> CachedCard? {
        // Space-separated archetypes (e.g. "Dragapult Dusknoir") need the greedy word scan
        // to correctly identify multi-word Pokémon names like "Dragapult ex".
        if !archetype.contains("/") {
            return resolveMultiple(archetype: archetype, from: cards, maxCount: 1).first
        }

        let primaryName = archetype
            .split(separator: "/", maxSplits: 1)
            .first
            .map { $0.trimmingCharacters(in: .whitespaces) }
            ?? archetype.trimmingCharacters(in: .whitespaces)

        let pokemonCards = cards.filter { $0.supertype == "Pokémon" }
        let normalised = primaryName.lowercased()

        // Prefer cards from the standard CDN; fall back to full pool only if none match.
        // This avoids returning promo/alternate-set cards that use unreliable third-party image hosts.
        let preferred = pokemonCards.filter { $0.imageURL.contains("pokemontcg.io") }
        let pool = preferred.isEmpty ? pokemonCards : preferred

        if let exact = pool.first(where: { $0.name.lowercased() == normalised }) {
            return exact
        }

        return pool.first {
            $0.name.lowercased().hasPrefix(normalised) ||
            normalised.hasPrefix($0.name.lowercased())
        }
    }
}
