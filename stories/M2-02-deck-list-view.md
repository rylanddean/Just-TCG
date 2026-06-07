# M2-02 — Deck List View

**Status:** todo  
**Milestone:** M2 — Deck Builder  
**Dependencies:** M2-01

## User Story
As a user, I want to see all my saved decks on the Decks tab so that I can quickly open or manage any deck.

## Acceptance Criteria

- [ ] Decks tab shows a list of saved decks, sorted by `updatedAt` descending (most recently edited first)
- [ ] Each row shows: deck name, card count (e.g. "42/60"), and `updatedAt` relative date (e.g. "2 days ago")
- [ ] A "+" button in the navigation bar opens the new deck creation flow (M2-03)
- [ ] Swipe-to-delete removes a deck (with a confirmation alert: "Delete [name]? This cannot be undone.")
- [ ] Empty state: "No decks yet — tap + to create your first deck"
- [ ] Tapping a deck navigates to the deck detail / builder view (M2-03)

## Technical Notes

- Use `@Query(sort: \Deck.updatedAt, order: .reverse)` for the deck list
- Row card count is `deck.cards.reduce(0) { $0 + $1.quantity }` — computed, not stored
- Confirmation alert uses `.confirmationDialog` or `.alert` with destructive button
