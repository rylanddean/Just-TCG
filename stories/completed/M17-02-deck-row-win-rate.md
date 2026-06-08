# M17-02 — Deck Row Win Rate

**Status:** done  
**Milestone:** M17 — Deck List UX  
**Dependencies:** none

## User Story

As a player, I want to see my win percentage for each deck on the Decks tab so I can quickly gauge how a deck is performing without opening it.

## Acceptance Criteria

- [x] The `updatedAt` timestamp in `DeckRowView` is replaced with a win-rate display
- [x] Win rate is calculated as `wins / (wins + losses + ties) * 100`, rounded to the nearest integer, where wins/losses/ties are counts of `Match` records with the corresponding `MatchResult` on `deck.matches`
- [x] If the deck has no recorded matches the slot shows `"—"` in a secondary foreground style
- [x] If the deck has at least one match the slot shows `"68%"` (integer, no decimal) followed by `" win rate"` as a secondary label (e.g. `"68% win rate"`) or combine into `Text("\(pct)%").font(.subheadline) + Text(" · \(total) games").font(.caption).foregroundStyle(.secondary)` — choose whichever reads most cleanly
- [x] Win rate text uses `.primary` foreground colour when ≥ 50 % and `.secondary` when < 50 % (with no matches also `.secondary`)
- [x] The match count (e.g. `"12 games"`) is shown beside the percentage in a lighter weight so the player knows the sample size
- [x] The layout still fits within the single-line second row alongside the `cardCount/60` info

## Technical Notes

**File to change:** `JustTCG/Features/Decks/DecksView.swift`

**Computed properties to add to `DeckRowView`:**
```swift
private var totalMatches: Int { deck.matches.count }
private var wins: Int { deck.matches.filter { $0.result == .win }.count }
private var winRate: Int? {
    guard totalMatches > 0 else { return nil }
    return Int(Double(wins) / Double(totalMatches) * 100)
}
```

**Display snippet** (replaces the `Text(deck.updatedAt, format: .relative(...))` call):
```swift
if let pct = winRate {
    Text("\(pct)%")
        .foregroundStyle(pct >= 50 ? .primary : .secondary)
    + Text(" · \(totalMatches) games")
        .foregroundStyle(.secondary)
} else {
    Text("—")
        .foregroundStyle(.secondary)
}
```

The existing `Spacer()` between card-count and the right-side slot is retained so the win-rate text stays trailing-aligned.

No new models or repositories needed — `deck.matches` is already an eager relationship on `Deck`.
