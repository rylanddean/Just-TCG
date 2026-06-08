# M19-01 — LiveGame & GameTurn SwiftData Models

**Status:** done  
**Milestone:** M19 — Live Game Mode  
**Dependencies:** none

## User Story

As a player, I want the app to record a structured log of every turn while I play — including how long each turn took and when prizes were taken — so that my completed games produce richer match records than a simple win/loss.

## Acceptance Criteria

- [x] A new `LiveGame` SwiftData model is added with:
  - `id: UUID`
  - `startedAt: Date`
  - `endedAt: Date?` — nil while the game is in progress
  - `opponentArchetype: String`
  - `eventType: EventType`
  - `format: MatchFormat`
  - `isPlayerGoingFirst: Bool`
  - `playerPrizesRemaining: Int` — starts at 6, decremented as the player takes prizes
  - `opponentPrizesRemaining: Int` — starts at 6, decremented as the opponent takes prizes
  - `deck: Deck?` — the deck being played
  - `match: Match?` — set after end-game finalization; nil for in-progress games
  - `@Relationship(deleteRule: .cascade) var turns: [GameTurn] = []`
- [x] A new `GameTurn` SwiftData model is added with:
  - `id: UUID`
  - `turnNumber: Int` — 1-indexed; increments each time any player ends their turn
  - `isPlayerTurn: Bool` — true if this is the local player's turn
  - `startedAt: Date`
  - `endedAt: Date?` — nil while the turn is active
  - `playerPrizesAtStart: Int` — snapshot of `playerPrizesRemaining` when this turn began
  - `opponentPrizesAtStart: Int` — snapshot of `opponentPrizesRemaining` when this turn began
  - `prizesTaken: Int` — prizes taken by the active player during this turn (usually 0–2)
  - `game: LiveGame?` — inverse relationship
- [x] `Match` gains an optional back-reference: `var liveGame: LiveGame?`
  - This is NOT a cascade delete — deleting a match should not destroy the live game log
- [x] `LiveGame.self` and `GameTurn.self` are registered in the `UserData` ModelConfiguration in `JustTCGApp.swift`
- [x] A `LiveGameRepository` is added at `JustTCG/Data/Repositories/LiveGameRepository.swift` with the following methods:
  - `startGame(deck:opponentArchetype:eventType:format:isPlayerGoingFirst:) -> LiveGame`
  - `startTurn(game:isPlayerTurn:) -> GameTurn` — creates and appends a new turn, sets `endedAt` on the previous turn
  - `recordPrizeTaken(game:byPlayer:)` — decrements the appropriate `…PrizesRemaining` counter and increments `prizesTaken` on the current open turn; `byPlayer: Bool`
  - `endGame(game:result:notes:) -> Match` — sets `game.endedAt`, closes the active turn, calls `MatchRepository.logMatch`, sets `game.match`

## Technical Notes

**New files:**
- `JustTCG/Data/Models/LiveGame.swift`
- `JustTCG/Data/Models/GameTurn.swift`
- `JustTCG/Data/Repositories/LiveGameRepository.swift`

**Files to change:**
- `JustTCG/Data/Models/Match.swift` — add `var liveGame: LiveGame?`
- `JustTCG/App/JustTCGApp.swift` — add `LiveGame.self`, `GameTurn.self` to `UserData` schema and top-level schema array

**Turn ordering:** `turns` is an unordered SwiftData relationship; sort by `turnNumber` or `startedAt` wherever displayed. `LiveGameRepository.startTurn` sets `turnNumber = (game.turns.map(\.turnNumber).max() ?? 0) + 1`.

**No seed-key bump needed** — `CachedCard` is unchanged. The `UserData` schema change will trigger a CloudKit migration automatically.

```swift
// LiveGame.swift sketch
@Model
final class LiveGame {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var opponentArchetype: String
    var eventType: EventType
    var format: MatchFormat
    var isPlayerGoingFirst: Bool
    var playerPrizesRemaining: Int
    var opponentPrizesRemaining: Int
    var deck: Deck?
    var match: Match?
    @Relationship(deleteRule: .cascade) var turns: [GameTurn] = []

    init(opponentArchetype: String, eventType: EventType, format: MatchFormat, isPlayerGoingFirst: Bool) {
        self.id = UUID()
        self.startedAt = .now
        self.opponentArchetype = opponentArchetype
        self.eventType = eventType
        self.format = format
        self.isPlayerGoingFirst = isPlayerGoingFirst
        self.playerPrizesRemaining = 6
        self.opponentPrizesRemaining = 6
    }
}

// GameTurn.swift sketch
@Model
final class GameTurn {
    var id: UUID
    var turnNumber: Int
    var isPlayerTurn: Bool
    var startedAt: Date
    var endedAt: Date?
    var playerPrizesAtStart: Int
    var opponentPrizesAtStart: Int
    var prizesTaken: Int
    var game: LiveGame?

    var duration: TimeInterval? {
        guard let end = endedAt else { return nil }
        return end.timeIntervalSince(startedAt)
    }
}
```
