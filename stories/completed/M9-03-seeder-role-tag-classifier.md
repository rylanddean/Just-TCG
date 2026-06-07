# M9-03 — Seeder Role Tag Classifier

**Status:** done  
**Milestone:** M9 — Card Role Tag Filtering  
**Dependencies:** M9-02

## User Story

As a developer, I want the bundled card seeder to populate `roleTags` on every `CachedCard` so that ability and attack text is classified once at seed time rather than at every filter evaluation.

## Acceptance Criteria

- [x] `AbilitySeedEntry` gains `text: String` decoded from the `"text"` key in the JSON
- [x] `AttackSeedEntry` gains `name: String` and `text: String` decoded from their respective JSON keys
- [x] A private `CardTagClassifier` enum in `BundledCardSeeder.swift` exposes a single method:
  ```swift
  static func tags(abilities: [AbilitySeedEntry], attacks: [AttackSeedEntry]) -> [String]
  ```
  It returns a **sorted, deduplicated** array of canonical tag strings from the M9-01 taxonomy.
- [x] Classification rules match the M9-01 taxonomy exactly (including extended rules for Energy Acceleration via "move", Spread Damage via place/put regex, Lock via "no Abilities"/"can't be moved", Disruption via devolve/hand-shuffle/cost-more)
- [x] `BundledCardSeeder` passes `entry.abilities` and `entry.attacks` to `CardTagClassifier.tags(abilities:attacks:)` and assigns the result to `CachedCard.roleTags`
- [x] After seeding, a `print` statement logs the top-5 most common tag combinations (for QA; can be removed later)

## Technical Notes

- All keyword matching uses `localizedCaseInsensitiveContains` on `String` except for Status and Spread Damage which use exact capitalised substrings as they appear in printed card text.
- Some rules overlap intentionally (e.g. an ability can be both `Draw` and `Search`). Tags are not mutually exclusive.
- `AttackSeedEntry.text` decodes via `decodeIfPresent` defaulting to `""` — many attacks have no text (pure damage attacks).
- `CardTagClassifier` is a private nested enum inside `BundledCardSeeder.swift` — it is only ever called from the seeder.
