# M3-02 — Bundled Archetype List

**Status:** todo  
**Milestone:** M3 — Match Tracker  
**Dependencies:** M0

## User Story
As a user, when I log a match I want to pick my opponent's deck from a curated list of current meta archetypes so that my matchup data is consistently labelled and can be aggregated correctly in analytics.

## Acceptance Criteria

- [ ] A `archetypes.json` file is bundled in the app target (not in Assets.xcassets — just in the bundle)
- [ ] The JSON contains at least the top 20 current Standard meta archetypes for the current rotation (2025–2026 season)
- [ ] Each archetype entry has: `id: String`, `name: String`, `primaryType: String` (e.g. `"Fire"`)
- [ ] `ArchetypeRepository` in `Domain/Entities/ArchetypeRepository.swift` loads and returns the list, sorted alphabetically
- [ ] The archetype list is accessed synchronously (loaded once at app start, held in memory)
- [ ] Fuzzy search: `ArchetypeRepository.search(query: String) -> [Archetype]` returns archetypes whose name contains the query (case-insensitive)
- [ ] If the user types an archetype not in the list, their freeform input is accepted as-is

## Technical Notes

- Current meta archetypes to seed (update before ship): Charizard ex / Pidgeot ex, Dragapult ex, Snorlax Stall, Gardevoir ex, Raging Bolt ex, Terapagos ex, Regidrago VSTAR, Lugia VSTAR, Giratina VSTAR, Miraidon ex, Iron Thorns ex, Roaring Moon ex, Ceruledge ex, Iron Valiant ex, Klawf Stall, Lost Box Comfey, Gholdengo ex, Arceus VSTAR / Giratina, Radiant Charizard / Turbo, Chien-Pao ex / Baxcalibur
- `Archetype` is a plain `struct`, not a SwiftData model — these are not user data
