# M1-05 — Card Search & Filter

**Status:** done  
**Milestone:** M1 — Card Browser  
**Dependencies:** M1-04

## User Story
As a user, I want to search and filter the card pool by name, type, and set so that I can quickly find the specific cards I'm looking for when building a deck.

## Acceptance Criteria

- [ ] A search bar at the top of the card browse view filters by card name (case-insensitive, partial match)
- [ ] A filter sheet (accessible via a filter icon button) offers:
  - **Type** multi-select: Fire, Water, Grass, Lightning, Psychic, Fighting, Darkness, Metal, Dragon, Colorless
  - **Set** multi-select: all sets present in the local cache, sorted newest first
  - **Subtype** multi-select: Pokémon ex, Pokémon V, VMAX, VSTAR, Basic, Stage 1, Stage 2, Item, Supporter, Stadium, Tool, Energy
- [ ] Active filters are shown as chips below the search bar; tapping a chip removes that filter
- [ ] "Clear all" button removes all active filters at once
- [ ] Filters compose additively (type AND set AND subtype)
- [ ] All filtering runs locally against the SwiftData cache — no network requests
- [ ] Filter state persists within the session but resets when the app is cold-launched

## Technical Notes

- Filtering uses `FetchDescriptor<CachedCard>` with `#Predicate` — avoid pulling all cards into memory and filtering in Swift
- `types` and `subtypes` are stored as `[String]` on `CachedCard` — predicate: `card.types.contains(selectedType)`
- The filter sheet is a `.sheet` presented from the toolbar filter button
- Filter chips use a `FlowLayout` or `ScrollView(.horizontal)` depending on chip count
