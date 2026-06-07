# M4-01 — Matchup Stats Engine

**Status:** todo  
**Milestone:** M4 — Analytics  
**Dependencies:** M3-01

## User Story
As a developer, I need a `MatchupStatsEngine` that computes win rates by opponent archetype from logged match data so that the analytics views have accurate, reactive data to display.

## Acceptance Criteria

- [ ] `MatchupStat` struct in `Domain/Entities/MatchupStat.swift`:
  - `archetype: String`, `wins: Int`, `losses: Int`, `ties: Int`
  - Computed: `winRate: Double` (wins / total; returns 0 if no games), `sampleSize: Int`
  - Computed: `confidence: MatchupConfidence` — `.sufficient` if sampleSize ≥ 5, else `.insufficient`
- [ ] `MatchupTag` enum: `.favourable` (winRate ≥ 0.60, sufficient), `.unfavourable` (winRate ≤ 0.40, sufficient), `.even` (0.40 < winRate < 0.60, sufficient), `.insufficientData`
- [ ] `MatchupStatsEngine` in `Domain/Entities/MatchupStatsEngine.swift`:
  - `func compute(matches: [Match]) -> [MatchupStat]` — groups by `opponentArchetype`, sorted by sampleSize desc
  - `func compute(matches: [Match], since: Date) -> [MatchupStat]` — filtered by date range
  - `func overallRecord(matches: [Match]) -> (wins: Int, losses: Int, ties: Int)`
- [ ] Unit tests cover: empty input, single archetype, multiple archetypes, tie-only matchup

## Technical Notes

- `MatchupStatsEngine` is a pure `struct` — no SwiftData, no side effects
- Grouping: `Dictionary(grouping: matches, by: \.opponentArchetype).mapValues { group in MatchupStat(...) }`
- Tie counts toward sample size but not toward wins
