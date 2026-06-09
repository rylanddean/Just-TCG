# M19-04 — Live Game Analytics

**Status:** done  
**Milestone:** M19 — Live Game Mode  
**Dependencies:** M19-01, M19-03

## User Story

As a player, I want to see deeper per-game stats on matches that were tracked live — like how long each turn took and how the prize race played out — so I can spot patterns in how my games actually unfold.

## Acceptance Criteria

### Match Detail Enrichment
- [x] `MatchDetailView` gains a "Live Data" section that appears only when `match.liveGame != nil`
- [x] The section shows:
  - **Game duration** — total time from `startedAt` to `endedAt` (formatted as "32m 14s")
  - **Total turns** — `game.turns.count`
  - **Avg. turn length (me)** — mean duration of completed player turns, formatted as `MM:SS`
  - **Avg. turn length (opp.)** — mean duration of completed opponent turns
  - **Longest turn** — max turn duration with the turn number, formatted "Turn 4 · 8m 12s"

### Prize Progression Chart
- [x] A line or step chart displays the prize race over the course of the game
- [x] X-axis: turn number; Y-axis: prizes remaining (0–6)
- [x] Two series: "My Prizes" (blue/accent) and "Opponent Prizes" (red/secondary)
- [x] The chart uses Swift Charts (`import Charts`)
- [x] The chart is shown in the "Live Data" section of `MatchDetailView`

### Deck-level Aggregate Stats
- [x] `DeckDetailView` (or the Analytics tab for that deck) gains an "Average Game Length" stat derived from all completed `LiveGame` records for that deck where `endedAt != nil`
- [x] "Avg. turns per game" is computed the same way
- [x] These stats only appear if the deck has at least 3 live-tracked games (to avoid misleading single-game averages)

### Analytics Engines
- [x] A new `LiveGameStatsEngine` struct at `JustTCG/Domain/Entities/LiveGameStatsEngine.swift` provides pure functions over `[LiveGame]`:
  - `averageDuration(games:) -> TimeInterval?`
  - `averageTurnsPerGame(games:) -> Double?`
  - `averagePlayerTurnDuration(game:) -> TimeInterval?`
  - `averageOpponentTurnDuration(game:) -> TimeInterval?`
  - `prizeProgressionSeries(game:) -> [(turn: Int, playerPrizes: Int, opponentPrizes: Int)]`

## Technical Notes

**New file:** `JustTCG/Domain/Entities/LiveGameStatsEngine.swift`

**Files to change:**
- `JustTCG/Features/Decks/MatchDetailView.swift` — add "Live Data" section
- `JustTCG/Features/Decks/DeckDetailView.swift` or `JustTCG/Features/Analytics/AnalyticsView.swift` — add deck-level live stats row

**Prize progression series** — reconstruct from turn snapshots:
```swift
func prizeProgressionSeries(game: LiveGame) -> [(turn: Int, playerPrizes: Int, opponentPrizes: Int)] {
    game.turns
        .sorted { $0.turnNumber < $1.turnNumber }
        .map { turn in
            (
                turn: turn.turnNumber,
                playerPrizes: turn.playerPrizesAtStart,
                opponentPrizes: turn.opponentPrizesAtStart
            )
        }
}
```

**Completed turn filter** (only turns with a recorded `endedAt` contribute to averages):
```swift
let completedPlayerTurns = game.turns.filter { $0.isPlayerTurn && $0.endedAt != nil }
```

**`TimeInterval` formatting helper** — add to an existing extensions file or a new one:
```swift
extension TimeInterval {
    var mmss: String {
        let m = Int(self) / 60
        let s = Int(self) % 60
        return String(format: "%d:%02d", m, s)
    }
}
```
