# M5-02 — Tournament Detail View

**Status:** done  
**Milestone:** M5 — Tournament Feed  
**Dependencies:** M5-01

## User Story
As a user, I want to tap a tournament and see the full standings so that I can understand how the meta played out at that event.

## Acceptance Criteria

- [ ] Tapping a tournament navigates to a detail view showing:
  - Tournament name, date, location, player count
  - Tab or segment picker: **Standings** / **Meta Share**
- [ ] **Standings tab**: list of placements — rank, player name, deck archetype, record (W–L–T)
  - Filtered to Top 8 by default; a "Show more" expands to Top 32 then full standings
- [ ] **Meta Share tab**: bar chart or ranked list of archetype share % at this event (e.g. "Charizard ex — 18.4%")
- [ ] Each placement row is tappable → opens the deck list viewer (M5-03)
- [ ] If deck list is not available for a placement, the row is non-tappable with a "Decklist not public" note

## Technical Notes

- `LimitlessTCGClient.fetchTournamentDetail(id:)` returns `LimitlessTournamentDetail` with `placements: [LimitlessPlacement]`
- `LimitlessPlacement`: `rank`, `playerName`, `archetype`, `wins`, `losses`, `ties`, `hasDeckList`
- Meta share is computed from placements: group by archetype, count, divide by total players
- Use Swift Charts for the meta share bar chart
