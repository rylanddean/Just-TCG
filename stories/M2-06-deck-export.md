# M2-06 — Deck Export

**Status:** todo  
**Milestone:** M2 — Deck Builder  
**Dependencies:** M2-03

## User Story
As a user, I want to export my deck list as text in PTCGL format so that I can copy-paste it into Pokémon TCG Live to proxy and playtest the deck.

## Acceptance Criteria

- [ ] An export button (share icon) in the deck detail view toolbar opens the iOS `ShareSheet`
- [ ] The exported text matches PTCGL copy-paste format exactly:
  ```
  Pokémon: 12
  4 Charizard ex OBF 223
  2 Charmander OBF 26

  Trainer: 38
  4 Professor's Research SVI 189

  Energy: 10
  10 Fire Energy SVE 2

  Total Cards: 60
  ```
- [ ] Cards within each section are sorted alphabetically by name
- [ ] The share sheet includes both "Copy" and standard share destinations
- [ ] Export works on incomplete decks (< 60 cards) — Total Cards reflects the actual count

## Technical Notes

- `DeckExporter.export(_ deck: Deck, cards: [CachedCard]) -> String` — pure function in `Domain/Entities/`
- Set code and card number come from `CachedCard.setCode` and `CachedCard.number`
- Section grouping logic is shared with `DeckBuilderViewModel` — extract a `DeckGrouper` helper to avoid duplication
