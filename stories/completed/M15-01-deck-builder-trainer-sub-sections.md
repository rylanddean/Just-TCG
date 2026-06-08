# M15-01 — Deck Builder: Split Trainer Section into Sub-Sections

**Status:** done  
**Area:** M2 — Deck Builder  
**Related stories:** M2-03, M2-04

## Description

The Trainer section in `DeckBuilderView` is currently a single flat list. Real Pokémon TCG decks typically run 25–35 trainers spanning very different card types (Supporters, Items, Tools, Stadiums, and Ace Specs). Grouping them by sub-section makes the deck at a glance much more readable and mirrors how players naturally think about their deck construction.

The Energy section is unchanged — all Basic and Special Energy cards remain in a single "Energy" section.

## Desired Behaviour

Replace the single `Section("Trainer · N")` with up to five sub-sections, each only rendered when non-empty:

| Sub-section header | Subtype value in `CachedCard.subtypes` |
|---|---|
| Supporter | `"Supporter"` |
| Item | `"Item"` |
| Tool | `"Pokémon Tool"` |
| Stadium | `"Stadium"` |
| Ace Spec | `"ACE SPEC"` |

Cards that carry more than one of these subtypes (edge case) fall into the first matching bucket in the order above.

Each sub-section header follows the existing `sectionTitle(_:cards:)` pattern: `"Supporter · 8"`, `"Item · 11"`, etc.

## Implementation Plan

### 1. `DeckGrouper`

Add a `TrainerGroups` nested struct inside `Groups`:

```swift
struct TrainerGroups {
    let supporter: [DeckCard]
    let item:      [DeckCard]
    let tool:      [DeckCard]
    let stadium:   [DeckCard]
    let aceSpec:   [DeckCard]
}
```

Replace the single `trainer: [DeckCard]` in `Groups` with `trainerGroups: TrainerGroups`.

Update `group(_:cardMap:)` to partition trainer cards into the five buckets using priority order:
1. `subtypes.contains("Supporter")`
2. `subtypes.contains("Item")`
3. `subtypes.contains("Pokémon Tool")`
4. `subtypes.contains("Stadium")`
5. `subtypes.contains("ACE SPEC")`

Cards matching none of the above (shouldn't happen in practice) fall into `item` as a safe default.

### 2. `DeckBuilderViewModel`

Replace:
```swift
var trainerCards: [DeckCard] { groups.trainer }
```
With five computed properties:
```swift
var supporterCards: [DeckCard] { groups.trainerGroups.supporter }
var itemCards:      [DeckCard] { groups.trainerGroups.item }
var toolCards:      [DeckCard] { groups.trainerGroups.tool }
var stadiumCards:   [DeckCard] { groups.trainerGroups.stadium }
var aceSpecCards:   [DeckCard] { groups.trainerGroups.aceSpec }
```

Also add a helper used by the existing `cardIds(forName:)` and validation scroll — no change needed there since it already iterates `deck.cards`.

### 3. `DeckBuilderView`

Replace `trainerSection(vm:)` with five `@ViewBuilder` functions following the same pattern as `pokemonSection`:

```swift
private func supporterSection(vm:) -> some View
private func itemSection(vm:)      -> some View
private func toolSection(vm:)      -> some View
private func stadiumSection(vm:)   -> some View
private func aceSpecSection(vm:)   -> some View
```

In `builderList`, replace the single `trainerSection(vm: vm)` call with:
```swift
supporterSection(vm: vm)
itemSection(vm: vm)
toolSection(vm: vm)
stadiumSection(vm: vm)
aceSpecSection(vm: vm)
```

Ordering in the list: Pokémon → Supporter → Item → Tool → Stadium → Ace Spec → Energy → Add Cards → Match History.

## Acceptance Criteria

- [x] Trainer cards are displayed in up to five labelled sub-sections: Supporter, Item, Tool, Stadium, Ace Spec
- [x] Each sub-section is hidden when it contains zero cards
- [x] Each sub-section header shows the correct count (e.g. `"Supporter · 4"`)
- [x] Cards within each sub-section are sorted alphabetically by name (same as before)
- [x] Energy section is unaffected
- [x] Validation scroll-to-card still works (existing `cardIds(forName:)` logic unchanged)
- [x] No regression in deck import, export, or legality validation

## Technical Notes

- Files to change: `DeckGrouper.swift`, `DeckBuilderViewModel.swift`, `DeckBuilderView.swift`
- The `sectionTitle(_:cards:)` helper in `DeckBuilderView` can be reused as-is for all five sub-sections
- `DeckValidator` and `DeckExporter` reference `deck.cards` directly — no changes needed there
