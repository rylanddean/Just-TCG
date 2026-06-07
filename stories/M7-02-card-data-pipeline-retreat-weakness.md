# M7-02 — Card Data Pipeline: Retreat, Weakness & Resistance

**Status:** todo  
**Milestone:** M7 — Advanced Card Filters  
**Dependencies:** M7-01

## User Story

As a user, I want to filter cards by retreat cost, weakness type, and resistance type so that I can quickly find Pokémon that fit specific matchup needs (e.g. "one-retreat Grass Pokémon with no Fighting weakness").

## Acceptance Criteria

- [ ] The card JSON schema gains three new optional fields per Pokémon card:
  - `retreatCost: Int?` — number of energy symbols in the retreat cost (0–4; `null` for Trainers/Energy)
  - `weaknessType: String?` — energy type of the weakness (e.g. `"Fire"`); `null` if none
  - `resistanceType: String?` — energy type of the resistance (e.g. `"Metal"`); `null` if none
- [ ] All 15 bundled set JSON files are regenerated with these fields populated
- [ ] `CardSeedEntry` adds matching `Decodable` properties (all optional, default `nil`)
- [ ] `CachedCard` adds matching stored properties:
  - `retreatCost: Int?`
  - `weaknessType: String?`
  - `resistanceType: String?`
- [ ] `BundledCardSeeder` maps the three new fields into `CachedCard`
- [ ] `seededKey` bumped to `"bundled_cards_seeded_v3"`
- [ ] Cards that are Trainer or Energy cards have `nil` for all three fields (expected behaviour)

## Data Pipeline Notes

The scraper (outside the Xcode project) should source these fields from the Pokémon TCG API (`api.pokemontcg.io/v2/cards`):

```
retreatCost  ← card.convertedRetreatCost          (Int)
weaknessType ← card.weaknesses[0].type            (String, strip "×2")
resistanceType ← card.resistances[0].type         (String, strip "-30")
```

For Limitless-sourced sets that lack a pokemontcg.io mapping, parse from the Limitless card detail page:
- Retreat cost: count energy symbols in the retreat row of the card stats table
- Weakness/Resistance: first word of the stat row (e.g. `"Fire ×2"` → `"Fire"`)

## Technical Notes

- Only `weaknessType` and `resistanceType` store the *type string* — not the multiplier or value, since the filter only needs "does this card have a Fire weakness?" not the exact modifier
- In the current Scarlet & Violet era, all weaknesses are `×2` and all resistances are `-30`, so stripping the modifier is safe; store just the type name
- No SwiftData migration schema required — adding nullable properties to an existing `@Model` is handled automatically at first launch after the `seededKey` bump
- If a future API returns multiple weaknesses or resistances, only store the first; multi-weakness cards are not present in current Standard
