# M6-01 — Meta Share Engine

**Status:** todo  
**Milestone:** M6 — Meta Comparison  
**Dependencies:** M5-02

## User Story
As a developer, I need a `MetaShareEngine` that aggregates archetype popularity across recent tournaments so that meta comparison views have a reliable signal for what the current field looks like.

## Acceptance Criteria

- [ ] `MetaShare` struct: `archetype: String`, `sharePercent: Double`, `tournaments: Int` (number of events included)
- [ ] `MetaShareEngine.compute(tournaments: [LimitlessTournamentDetail]) -> [MetaShare]`:
  - Aggregates player counts across all provided tournaments
  - Groups by archetype, sums player counts, divides by total players across all events
  - Returns sorted by sharePercent desc
- [ ] `MetaShareEngine.topArchetypes(limit: Int, ...) -> [MetaShare]` returns the top N archetypes
- [ ] The engine accepts 1–10 recent tournaments (configurable); default is last 5 Regionals or higher
- [ ] Unit tests cover: single tournament, multiple tournaments, archetype normalisation (same archetype, different capitalisation should merge)

## Technical Notes

- Archetype normalisation: lowercase + trim before grouping
- `MetaShareEngine` is a pure `struct` — no I/O, no SwiftData
- Sourcing the tournament data: `TournamentRepository` fetches and caches the last N tournament details, feeds them to the engine
