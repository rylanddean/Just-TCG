# M19-03 — Live Game HUD

**Status:** done  
**Milestone:** M19 — Live Game Mode  
**Dependencies:** M19-01, M19-02

## User Story

As a player, I want a full-screen HUD while I'm playing a game so I can track prizes, time turns, and see the game clock — all without leaving the app or fumbling with controls.

## Acceptance Criteria

### Prize Tracking
- [x] Both the player's and opponent's prize piles are represented as **6 tappable circles** arranged in a 2×3 grid
- [x] Player's prizes are at the bottom half of the screen; opponent's prizes are at the top half, mirrored
- [x] Each circle is filled (active prize) or crossed out / dimmed (prize taken)
- [x] Tapping a circle calls `LiveGameRepository.recordPrizeTaken(game:byPlayer:)` and triggers a brief haptic tap
- [x] Prize circles cannot be un-tapped (prizes aren't returned to the pile); long-pressing a taken prize shows a confirmation alert to reverse it in case of a mis-tap
- [x] The remaining prize count is shown as a large number beside each grid (e.g., "4" remaining)

### Turn & Clock Tracking
- [x] A **turn clock** shows elapsed time for the current turn, counting up in `MM:SS` format using a `TimelineView(.periodic(from:by:))`
- [x] A **game clock** shows total elapsed time since game start in `MM:SS`, always visible in a less prominent position
- [x] The active player's side is highlighted (e.g., accent-coloured border or background tint) to make it clear whose turn it is
- [x] An **"End Turn"** button calls `LiveGameRepository.startTurn(game:isPlayerTurn:)`, toggling whose turn it is and resetting the turn clock
- [x] The current turn number is displayed (e.g., "Turn 7")

### End Game
- [x] A **"End Game"** button (or discreet "⏹" icon in the top corner) presents a confirmation sheet
- [x] The confirmation sheet shows the current prize state and asks for the result: Win / Loss / Tie
- [x] An optional notes field is included (same as `LogMatchSheet`)
- [x] Confirming calls `LiveGameRepository.endGame(game:result:notes:)` which creates the `Match` record and dismisses the HUD
- [x] After dismissal, a toast on the originating screen reads "Game saved"

### Edge Cases
- [x] If either player reaches 0 prizes remaining, a "Game Over?" banner appears prompting the player to confirm the result immediately
- [x] The screen is kept awake (using `UIApplication.shared.isIdleTimerDisabled = true`) while the HUD is presented and restored to `false` on dismiss
- [x] The HUD works in portrait orientation; landscape is not required for V1

## Technical Notes

**New files:**
- `JustTCG/Features/LiveGame/LiveGameHUDView.swift`
- `JustTCG/Features/LiveGame/LiveGameHUDViewModel.swift`

**Screen-awake management:**
```swift
.onAppear { UIApplication.shared.isIdleTimerDisabled = true }
.onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
```

**Clock rendering** — use `TimelineView` to avoid a `Timer` publisher:
```swift
TimelineView(.periodic(from: turn.startedAt, by: 1)) { context in
    let elapsed = context.date.timeIntervalSince(turn.startedAt)
    Text(elapsed.mmss)  // extension on TimeInterval
}
```

**Layout sketch (portrait):**
```
┌─────────────────────────────┐
│  [game clock]   [end game]  │  ← small, top bar
│                             │
│   Opponent  ●●●  4 prizes   │  ← prize grid (top half)
│             ●●●             │
│  ─────────────────────────  │
│  Turn 7 · Their Turn  [03:12]│  ← turn banner + clock
│  ─────────────────────────  │
│             ○○○             │
│   You       ○●●  3 prizes   │  ← prize grid (bottom half)
│                             │
│        [End Turn]           │
└─────────────────────────────┘
```

**ViewModel:**
```swift
@Observable
final class LiveGameHUDViewModel {
    let game: LiveGame
    private let repo: LiveGameRepository

    var activeTurn: GameTurn? { game.turns.max(by: { $0.turnNumber < $1.turnNumber }) }
    var isPlayerTurn: Bool { activeTurn?.isPlayerTurn ?? game.isPlayerGoingFirst }

    func endTurn() { repo.startTurn(game: game, isPlayerTurn: !isPlayerTurn) }
    func takePrize(byPlayer: Bool) { repo.recordPrizeTaken(game: game, byPlayer: byPlayer) }
}
```
