# M7-01 — Extended Card Data Model

**Status:** todo  
**Milestone:** M7 — Advanced Card Filters  
**Dependencies:** M1-02, M1-03

## User Story

As a developer, I want `CachedCard` to store the rich card data that already exists in the bundled JSON (attacks, abilities, regulation mark, rarity) so that advanced filter predicates can run against real fields rather than parsing `rulesText` strings.

## Acceptance Criteria

- [ ] `CachedCard` gains the following new stored properties:
  - `regulationMark: String?` — single letter (e.g. `"H"`, `"I"`, `"J"`)
  - `rarity: String?` — as printed (e.g. `"Common"`, `"Illustration Rare"`, `"Special Illustration Rare"`)
  - `hasAbility: Bool` — `true` if the card has one or more abilities
  - `maxDamage: Int?` — highest numeric damage value across all attacks (nil for Trainers/Energy)
  - `attackEnergyCosts: [String]` — deduplicated, sorted list of energy types that appear across all attack costs (e.g. `["Colorless", "Grass"]`)
- [ ] `CardSeedEntry` gains matching decodable fields (using existing JSON keys): `regulationMark`, `rarity`, `attacks`, `abilities`
- [ ] `BundledCardSeeder` maps these fields when constructing `CachedCard` instances:
  - `hasAbility = !entry.abilities.isEmpty`
  - `maxDamage` = parse numeric prefix from each `attack.damage` string (strip `"+"` suffix; `"180+"` → `180`), take the max; nil if no attacks
  - `attackEnergyCosts` = `Set(entry.attacks.flatMap(\.cost)).sorted()`
- [ ] `seededKey` bumped to `"bundled_cards_seeded_v2"` to force a re-seed on next launch
- [ ] All new `CachedCard` properties have sensible defaults in the `init` so existing code paths compile without change

## Technical Notes

- The existing JSON files (`CardData/*.json`) already contain `attacks`, `abilities`, and `regulationMark` — no scraper changes needed for this story
- `CardSeedEntry` needs a nested `AttackSeedEntry: Decodable` struct with `cost: [String]` and `damage: String` fields; `AbilitySeedEntry` needs only `name: String`
- `maxDamage` parsing: `Int(attack.damage.prefix(while: { $0.isNumber }))` — handles `""`, `"20"`, `"180+"`
- SwiftData requires explicit `@Attribute` for any array/primitive type change — adding properties to an existing `@Model` class is a lightweight migration; no `VersionedSchema` needed unless you hit a crash
- Do **not** store raw attack/ability objects as nested SwiftData models — the flat derived properties (`hasAbility`, `maxDamage`, `attackEnergyCosts`) are sufficient for filtering and avoid relationship complexity
