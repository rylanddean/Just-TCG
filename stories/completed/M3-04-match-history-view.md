# M3-04 — Match History View

**Status:** done  
**Milestone:** M3 — Match Tracker  
**Dependencies:** M3-03

## User Story
As a user, I want to see a chronological history of all matches I've logged for a deck so that I can review my recent results and edit or delete mistakes.

## Acceptance Criteria

- [ ] Deck detail view has a "Match History" section below the card list showing the last 5 matches with a "See all" link
- [ ] "See all" navigates to `MatchHistoryView` — a full list of all matches for the deck, sorted newest first
- [ ] Each match row shows: result pill (W/L/T, colour-coded), opponent archetype, event type, and relative date
- [ ] Swipe-to-delete removes a match (with confirmation: "Delete this match result?")
- [ ] Tapping a match row opens `MatchDetailView` — shows all fields and an edit button
- [ ] Edit mode allows updating: opponent archetype, result, event type, format, date, notes — saves on "Done"
- [ ] The overall record (e.g. "12W – 8L – 1T") is shown at the top of `MatchHistoryView`

## Technical Notes

- `@Query(filter: #Predicate { $0.deck?.id == deckId }, sort: \Match.date, order: .reverse)` for the full history list
- Result pill colours: Win = green, Loss = red, Tie = grey
- Overall record is computed, not stored
