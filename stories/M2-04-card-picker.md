# M2-04 — Card Picker (Add Cards to Deck)

**Status:** todo  
**Milestone:** M2 — Deck Builder  
**Dependencies:** M1-05, M2-03

## User Story
As a user, I want to search and browse Standard-legal cards from within the deck builder and add them to my deck so that I can construct my full 60-card list.

## Acceptance Criteria

- [ ] "Add Cards" opens a modal sheet with the full card search and filter UI (reuses M1-05 components)
- [ ] Each card row in the picker shows: thumbnail, name, set, current quantity in the deck (e.g. "2 in deck")
- [ ] Tapping a card increments its quantity in the deck by 1
- [ ] A long-press (or secondary button) opens the card detail view (M1-06) in context
- [ ] Cards already at their max quantity (4, or deck total 60) show a disabled state — cannot be tapped
- [ ] A persistent "Done" button closes the sheet and returns to the deck detail view
- [ ] The deck card count in the deck detail view updates live as cards are added

## Technical Notes

- The card picker is `CardPickerView` — it takes a `Deck` binding and delegates add/remove to `DeckRepository`
- Reuse `CardSearchView` and `CardFilterView` from M1-05; pass an `onSelect` closure instead of navigating
- Max quantity: 4 for all named cards except basic Energy — basic Energy check uses `CachedCard.subtypes.contains("Basic Energy")`
