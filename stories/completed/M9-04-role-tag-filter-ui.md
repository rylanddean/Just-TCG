# M9-04 — Role Tag Filter State & UI

**Status:** done  
**Milestone:** M9 — Card Role Tag Filtering  
**Dependencies:** M9-03

## User Story

As a player, I want to filter the card browser by what a card can do (Draw, Disruption, Energy Acceleration, etc.) so that I can quickly find cards that fill a specific role in my deck without manually reading every ability.

## Acceptance Criteria

- [x] `CardFilterState` gains one new field:
  - `roleTags: Set<String> = []` — selected role tags; card passes if its `roleTags` intersects this set (OR within set); empty = any
- [x] `CardFilterState.isEmpty` includes `roleTags.isEmpty`
- [x] `CardFilterState.passes(_ card: CachedCard)` returns `false` when `roleTags` is non-empty and `Set(card.roleTags).isDisjoint(with: roleTags)`
- [x] `CardFilterState.activeChips` appends a chip when `roleTags` is non-empty:
  - `id: "roleTags"`, `label: "Role: \(roleTags.sorted().joined(separator: ", "))"` (truncated to "Role: N roles" when count > 2)
- [x] `CardFilterState.clearChip(id:)` handles `"roleTags"` → `roleTags = []`
- [x] `CardFilterView` gains a new collapsible section **"Card Role"** containing a 2-column LazyVGrid of all 13 canonical tags in canonical order
- [x] Selected role tag chips use the same filled/outlined toggle style as existing filter chips (filled accentColor when selected, outlined when not)
- [x] The "Card Role" section collapses and expands consistently with the existing four sections in `CardFilterView`
- [x] Both `CardsView` and `CardPickerView` pass the updated `CardFilterState` through without any additional changes (the `passes(_:)` path already handles this)

## Technical Notes

- The canonical tag strings are defined as `static let allRoleTags: [String]` on `CardFilterState` so the filter sheet and the chip label never drift out of sync with the seeder.
- `roleTags` filter semantics: a card with `["Draw", "Search"]` passes a filter of `["Draw", "Disruption"]` because "Draw" intersects. This OR-within-set matches how `attackingEnergyTypes` works.
- Trainer and Energy cards will have empty `roleTags` and will be excluded when any role tag filter is active — this is acceptable and expected behaviour.
