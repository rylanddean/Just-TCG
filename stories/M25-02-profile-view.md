# M25-02 — Player Profile View

**Status:** todo  
**Milestone:** M25 — Player Profile  
**Dependencies:** M25-01, M11-01

## User Story

As a player, I want to tap my profile icon on the Home screen and see a summary of all my performance stats — total games, win rate, streaks, best and worst matchups, and my most-played deck — in one place.

## Acceptance Criteria

### Entry Point
- [ ] A circular person icon (`person.crop.circle`) is added to `HomeView`'s leading navigation bar position
- [ ] Tapping it presents `ProfileView` as a `.sheet`

### `ProfileView`
- [ ] New view at `JustTCG/Features/Profile/ProfileView.swift`
- [ ] Navigation bar title "Profile" with a "Done" dismiss button
- [ ] Queries all `Match` and `Deck` objects from SwiftData and computes `ProfileStats` via `ProfileStatsEngine`
- [ ] **Header section:**
  - Large SF Symbol avatar (`person.crop.circle.fill`) in accent colour
  - Player name displayed below (editable via `@AppStorage("playerName")`, tapping it opens an inline rename field)
  - "Member since" date derived from the oldest match or deck creation date
- [ ] **Stats grid (2×2 LazyVGrid):**
  - Total Games played
  - Win Rate (formatted as "XX.X%", "—" if no games)
  - Current Streak ("3W" or "2L" or "—")
  - Longest Win Streak
- [ ] **Most-Played Deck section:**
  - Shown only if `mostPlayedDeck != nil`
  - Displays the deck's cover card thumbnails (same row as `DecksView`), deck name, and its win rate
  - Tapping navigates to that deck's detail (requires dismiss + tab switch — out of scope; tappable but no navigation for now)
- [ ] **Matchups section:**
  - "Best matchup" row: archetype name + win rate (hidden if `bestMatchup == nil`)
  - "Toughest matchup" row: archetype name + win rate (hidden if `worstMatchup == nil`)
  - Subtitle "Minimum 5 games" shown if both are nil
- [ ] **Most Common Opponent:**
  - Single row: "Most faced: [Archetype name]"
  - Hidden if `topArchetypeFaced == nil`
- [ ] Empty state (no matches at all): a centred prompt "Log your first match to start building your profile."

## Technical Notes

**New files:**
- `JustTCG/Features/Profile/ProfileView.swift`

**Files to change:**
- `JustTCG/Features/Home/HomeView.swift` — add profile icon + sheet

**SwiftData queries:**
```swift
@Query private var allMatches: [Match]
@Query(sort: \Deck.updatedAt, order: .reverse) private var decks: [Deck]
```

**Stats computation:**
```swift
private var stats: ProfileStats {
    ProfileStatsEngine().compute(matches: allMatches, decks: decks)
}
```

**Streak display helper:**
```swift
private func streakLabel(_ streak: Int) -> String {
    if streak == 0 { return "—" }
    return streak > 0 ? "\(streak)W" : "\(abs(streak))L"
}
```

**Stats grid layout:**
```swift
LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
    StatCell(title: "Games", value: "\(stats.totalGames)")
    StatCell(title: "Win Rate", value: stats.winRate.map { String(format: "%.1f%%", $0 * 100) } ?? "—")
    StatCell(title: "Streak", value: streakLabel(stats.currentStreak))
    StatCell(title: "Best Streak", value: "\(stats.longestWinStreak)W")
}
```

where `StatCell` is a small private struct with a `title` caption and a `value` title2 text.
