# M25-01 — Profile Stats Engine

**Status:** done  
**Milestone:** M25 — Player Profile  
**Dependencies:** M3-01, M4-01

## User Story

As a developer, I need a pure stats engine that aggregates a player's overall performance data across all decks and matches so that the Profile View can display a meaningful high-level summary.

## Acceptance Criteria

- [x] A new struct `ProfileStatsEngine` is created at `JustTCG/Domain/Entities/ProfileStatsEngine.swift`
- [x] All functions are pure (no SwiftData dependency — accept arrays as input)
- [x] The engine exposes:

  ```swift
  struct ProfileStats {
      let totalGames: Int
      let wins: Int
      let losses: Int
      let ties: Int
      let winRate: Double?          // nil if totalGames == 0
      let currentStreak: Int        // positive = win streak, negative = loss streak
      let longestWinStreak: Int
      let bestMatchup: MatchupStat? // highest winRate with sampleSize >= 5
      let worstMatchup: MatchupStat?// lowest winRate with sampleSize >= 5
      let mostPlayedDeck: Deck?
      let topArchetypeFaced: String? // most frequently logged opponent archetype
  }
  ```

  ```swift
  struct ProfileStatsEngine {
      func compute(matches: [Match], decks: [Deck]) -> ProfileStats
  }
  ```

- [x] `winRate` is `Double(wins) / Double(totalGames)` — ties count as games played but not wins or losses
- [x] `currentStreak` is computed by walking matches sorted by date descending and counting consecutive wins (positive) or losses (negative) from the most recent match; a tie breaks the streak (result is 0)
- [x] `longestWinStreak` is the longest run of consecutive win results across all matches sorted by date ascending
- [x] `bestMatchup` and `worstMatchup` use `MatchupStatsEngine` results filtered to `sampleSize >= 5`
- [x] `mostPlayedDeck` is the `Deck` with the highest `matches.count`
- [x] `topArchetypeFaced` is the most frequent `opponentArchetype` across all matches
- [x] Unit tests in `JustTCGTests/ProfileStatsEngineTests.swift` cover: empty input, all wins, all losses, mixed record, streak calculation, best/worst matchup with insufficient data

## Technical Notes

**New files:**
- `JustTCG/Domain/Entities/ProfileStatsEngine.swift`
- `JustTCGTests/ProfileStatsEngineTests.swift`

**Streak computation:**
```swift
private func currentStreak(from matches: [Match]) -> Int {
    let sorted = matches.sorted { $0.date > $1.date }
    guard let first = sorted.first else { return 0 }
    var streak = first.result == .win ? 1 : first.result == .loss ? -1 : 0
    guard streak != 0 else { return 0 }
    for match in sorted.dropFirst() {
        if streak > 0 && match.result == .win  { streak += 1 }
        else if streak < 0 && match.result == .loss { streak -= 1 }
        else { break }
    }
    return streak
}
```
