# M5-01 — Tournament List

**Status:** todo  
**Milestone:** M5 — Tournament Feed  
**Dependencies:** M1-01

## User Story
As a user, I want to see a list of recent major Pokémon TCG tournaments so that I can stay up to date on the competitive meta.

## Acceptance Criteria

- [ ] Tournaments tab shows a list of recent events fetched from Limitless TCG, sorted by date (newest first)
- [ ] Each row shows: tournament name, date, location, event tier (e.g. "Regional Championship"), and number of players
- [ ] Event tier is shown as a coloured badge (Worlds = gold, IC = purple, Regional = blue, LC = grey)
- [ ] A filter bar allows filtering by event tier
- [ ] Pull-to-refresh fetches the latest results
- [ ] Results are cached to disk — displayed from cache when offline (with a "Last updated X ago" note)
- [ ] 1-hour in-memory cache prevents redundant fetches within a session

## Technical Notes

- `LimitlessTCGClient.fetchRecentTournaments(limit: 50)` added in M1-01
- `TournamentListViewModel` manages fetch + in-memory cache; disk cache is `URLCache`
- `LimitlessTournament` struct: `id`, `name`, `date`, `location`, `tier`, `playerCount`
- Tier maps to `EventType` enum from M3-01 for consistency
