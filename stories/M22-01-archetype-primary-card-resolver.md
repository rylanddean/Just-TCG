# M22-01 — Archetype Primary Card Resolver

**Status:** todo  
**Milestone:** M22 — Visual Meta Share  
**Dependencies:** M1-02, M6-01

## User Story

As a developer, I need a way to resolve an archetype name string (e.g. "Dragapult ex" or "Dragapult ex / Pidgeot ex") to the best-matching `CachedCard` in the local card cache, so that the visual meta share UI can display the primary card's art.

## Acceptance Criteria

- [ ] A new struct `ArchetypePrimaryCardResolver` is created at `JustTCG/Domain/Entities/ArchetypePrimaryCardResolver.swift`
- [ ] `resolve(archetype: String, from cards: [CachedCard]) -> CachedCard?` parses the archetype name and returns the best match
- [ ] Parsing strategy:
  1. Split the archetype string on `" / "` and take the first segment (e.g. "Dragapult ex / Pidgeot ex" → "Dragapult ex")
  2. Attempt an exact case-insensitive name match against `CachedCard.name`
  3. If no exact match, attempt a prefix match (archetype starts with card name or card name starts with archetype)
  4. Return `nil` if no match is found
- [ ] Only Pokémon cards (`supertype == "Pokémon"`) are candidates — Trainer / Energy cards are excluded
- [ ] The resolver is a pure function with no SwiftData dependency (accepts `[CachedCard]` directly)
- [ ] Unit tests in `JustTCGTests/ArchetypePrimaryCardResolverTests.swift` cover: exact match, slash-split archetype, prefix match, no-match returns nil, non-Pokémon excluded

## Technical Notes

**New file:** `JustTCG/Domain/Entities/ArchetypePrimaryCardResolver.swift`

```swift
struct ArchetypePrimaryCardResolver {
    func resolve(archetype: String, from cards: [CachedCard]) -> CachedCard? {
        let primaryName = archetype
            .split(separator: "/", maxSplits: 1)
            .first
            .map { $0.trimmingCharacters(in: .whitespaces) }
            ?? archetype.trimmingCharacters(in: .whitespaces)

        let pokemonCards = cards.filter { $0.supertype == "Pokémon" }
        let normalised = primaryName.lowercased()

        // 1. Exact match
        if let exact = pokemonCards.first(where: { $0.name.lowercased() == normalised }) {
            return exact
        }

        // 2. Prefix match — card name starts with the archetype token
        return pokemonCards.first {
            $0.name.lowercased().hasPrefix(normalised) ||
            normalised.hasPrefix($0.name.lowercased())
        }
    }
}
```

**New test file:** `JustTCGTests/ArchetypePrimaryCardResolverTests.swift`
