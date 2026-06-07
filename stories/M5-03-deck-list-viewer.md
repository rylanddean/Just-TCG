# M5-03 — Tournament Deck List Viewer

**Status:** todo  
**Milestone:** M5 — Tournament Feed  
**Dependencies:** M5-02, M1-02

## User Story
As a user, I want to view a tournament competitor's full deck list inline so that I can study what top players are playing and get inspiration for my own builds.

## Acceptance Criteria

- [ ] Tapping a placement with a deck list opens `DeckListDetailView` — a sheet or pushed view
- [ ] The deck list is displayed in the same grouped format as the deck builder (Pokémon / Trainer / Energy sections)
- [ ] Each card row shows: thumbnail, name, set, count — tapping opens the card detail view (M1-06) in context
- [ ] A "Copy List" button copies the deck in PTCGL export format to the clipboard
- [ ] An "Import to My Decks" button creates a new `Deck` in the user's saved decks, pre-populated with this list — opens the deck detail view after import
- [ ] Deck lists are cached to disk after first fetch

## Technical Notes

- `LimitlessTCGClient.fetchDeckList(tournamentId:, placement:)` returns `LimitlessDeckList` with `[LimitlessDeckEntry]` (cardId, quantity)
- Cross-reference `LimitlessDeckEntry.cardId` against `CachedCard` to get names and images — cards not in cache show name only (no image)
- "Import to My Decks" calls `DeckRepository.createDeck` then adds each entry via `DeckRepository.addCard` / `setQuantity`
