# M3-01 — Match SwiftData Model & Enums

**Status:** done  
**Milestone:** M3 — Match Tracker  
**Dependencies:** M2-01

## User Story
As a developer, I need a `Match` SwiftData model with all supporting enums so that match results can be persisted locally and synced via iCloud.

## Acceptance Criteria

- [x] `Match` `@Model` class in `Data/Models/Match.swift`:
  - `id: UUID`, `date: Date`, `opponentArchetype: String`, `result: MatchResult`, `format: MatchFormat`, `eventType: EventType`, `notes: String`, `deck: Deck?`
- [x] `MatchResult` enum: `.win`, `.loss`, `.tie` — `String` raw value, `Codable`
- [x] `MatchFormat` enum: `.bo1`, `.bo3` — `String` raw value, `Codable`
- [x] `EventType` enum: `.casual`, `.leagueChallenge`, `.regionals`, `.internationalChampionship`, `.worldChampionship` — `String` raw value, `Codable`
- [x] `Match` registered in the CloudKit-backed `ModelConfiguration`
- [x] `MatchRepository` in `Data/Repositories/MatchRepository.swift`:
  - `func logMatch(deck: Deck, archetype: String, result: MatchResult, format: MatchFormat, eventType: EventType, notes: String, date: Date) -> Match`
  - `func deleteMatch(_ match: Match)`
  - `func updateMatch(_ match: Match, notes: String)`
- [x] Wire the `matches` relationship stub back into `Deck` (declared in M2-01)

## Technical Notes

- Enums stored in SwiftData as `String` raw values — mark with `@Attribute` if needed for CloudKit compatibility
- `MatchRepository` takes `ModelContext` in initialiser
- `notes` defaults to `""` — never optional
