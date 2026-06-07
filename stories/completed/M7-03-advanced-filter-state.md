# M7-03 — Advanced Filter State & Predicate Engine

**Status:** done  
**Milestone:** M7 — Advanced Card Filters  
**Dependencies:** M7-01, M7-02

## User Story

As a user, I want to combine any mix of advanced filters (HP range, damage output, retreat cost, regulation mark, weakness, resistance, attacking energy, has ability, rarity) with the existing type/set/subtype filters so that complex multi-criteria searches return exactly the cards I need.

## Acceptance Criteria

- [x] `CardFilterState` is extended with:
  - `hpMin: Int?` — lower bound of HP filter (nil = no lower bound); step 10
  - `hpMax: Int?` — upper bound of HP filter (nil = no upper bound); step 10
  - `damageMin: Int?` — lower bound on `maxDamage`; step 10
  - `damageMax: Int?` — upper bound on `maxDamage`; step 10
  - `retreatCosts: Set<Int>` — selected retreat cost values (0–4); empty = any
  - `regulationMarks: Set<String>` — selected regulation mark letters; empty = any
  - `weaknessTypes: Set<String>` — selected weakness energy types; empty = any
  - `resistanceTypes: Set<String>` — selected resistance energy types; empty = any
  - `attackingEnergyTypes: Set<String>` — selected energy types; card must have ≥1 attack whose cost includes the selected type; empty = any
  - `hasAbility: Bool?` — `nil` = any, `true` = ability cards only, `false` = no-ability cards only
  - `rarities: Set<String>` — selected rarity strings; empty = any
- [x] `isEmpty` on `CardFilterState` returns `true` only when all fields (including new ones) are at their default "no filter" state
- [x] The predicate/filter logic in `CardsView` and `CardPickerView` is updated to apply all new filters
- [x] All filters compose with AND logic (a card must satisfy every active filter to appear)
- [x] Filters for HP and damage treat `nil` bounds as open-ended (`hpMin: 80, hpMax: nil` = HP ≥ 80)
- [x] `attackingEnergyTypes` filter matches if *any* attack cost contains *any* of the selected types (OR within the set, AND with other filters)
- [x] `retreatCosts` filter: card's `retreatCost` equals *any* selected value (OR within the set)
- [x] `weaknessTypes` / `resistanceTypes`: card's single weakness/resistance type is *any* of the selected values
- [x] Trainer and Energy cards (no HP, no attacks): pass HP/damage/retreat/ability filters transparently unless those filters are narrowly set (e.g. HP min > 0 excludes them naturally)

## Technical Notes

- SwiftData `#Predicate` does **not** support `.contains(_:)` on a stored `[String]` property when the argument is itself a collection — work around this with `attackingEnergyTypes.contains { card.attackEnergyCosts.contains($0) }` evaluated in a post-fetch Swift filter, or store a joined string and use `localizedStandardContains`
- Recommended architecture: fetch with a `FetchDescriptor<CachedCard>` using only the predicates that map cleanly to SwiftData predicates (name, type, set, subtype, HP bounds, retreat cost, regulationMark, hasAbility), then apply `attackingEnergyTypes`, `damageMin/Max`, `weaknessTypes`, `resistanceTypes`, and `rarities` in a subsequent Swift `.filter {}` pass — this keeps the fetch efficient while handling array-membership checks correctly
- Extract a `CardFilterState.predicate(availableEnergies:) -> Predicate<CachedCard>?` method and a `CardFilterState.passes(_ card: CachedCard) -> Bool` method for the post-fetch pass; both `CardsView` and `CardPickerView` use the same pair
- `CardFilterState` must remain `Equatable` so `onChange(of:)` can detect changes efficiently
- For the HP and damage range bounds, use `Int` not `Double` — Pokémon HP and damage are always multiples of 10
