# BUG-26 — Game Logs and Match Logs Are Separate Confusing Views

**Status:** done  
**Area:** Decks / Live Game

## Description

The deck detail screen exposes two distinct log concepts: **Match History** (`MatchHistoryView` — one row per manually-logged `Match`) and **Game Logs** (`GameLogListView` — one row per live `LiveGame`). Users see both, but the relationship between them is unclear. A `LiveGame` that ends normally creates a linked `Match`, so the same result appears in both lists — one as a live game record and one as a match result. The duplication and naming divergence ("Match History" vs. "Game Logs") creates confusion about which list is authoritative and what the difference is.

## Steps to Reproduce

1. Open any deck that has live game history
2. Note that "Match History" and "Game Logs" are separate navigable sections

## Observed Behaviour

- A completed live game shows an entry in Game Logs and a duplicate result entry in Match History (via `game.match`)
- "Game Logs" and "Match History" have near-identical row designs but are presented as unrelated screens
- Users have no single view to see their full game + match record in chronological order

## Desired Behaviour

A single "History" section in the deck shows all activity — manual match logs and live game sessions — in one unified, chronological list. Each row clearly indicates whether it came from a live session or was manually logged. Live game rows are expandable (or navigable) to the turn-by-turn detail.

## Acceptance Criteria

### Unified history view
- [ ] A new `DeckHistoryView` is created at `JustTCG/Features/Decks/DeckHistoryView.swift`
- [ ] It displays `Match` and `LiveGame` records interleaved in reverse-chronological order by date
- [ ] Each `Match` that was created from a `LiveGame` (i.e. `game.match != nil`) is **deduped**: only the `LiveGame` row is shown, not a separate `Match` row
- [ ] Manually-logged `Match` records (where no linked `LiveGame` exists) show as a plain match row identical to the current `MatchRow`
- [ ] `LiveGame` rows show a `"Live"` chip/badge to distinguish them; tapping navigates to a `LiveGameDetailView` (or the existing game log detail)

### Record header
- [ ] `DeckHistoryView` retains the W–L–T summary header from `MatchHistoryView`
- [ ] The count is computed from all `Match` records (both live-originated and manual) to avoid double-counting

### Removal of old views from deck detail
- [ ] `DeckBuilderView`'s separate "Game Logs" and "Match History" sections are replaced with a single "History" `NavigationLink` pointing to `DeckHistoryView`
- [ ] `GameLogListView` and `MatchHistoryView` remain in the codebase but are no longer reachable from `DeckBuilderView` (they may be cleaned up in a follow-on)

### No regressions
- [ ] `MatchLogWidget` on the home screen is unaffected
- [ ] Swipe-to-delete works on both row types in `DeckHistoryView`
- [ ] `LogMatchViewModel` and the manual log flow are unchanged

## Technical Notes

**New files:**
- `JustTCG/Features/Decks/DeckHistoryView.swift`

**Files to change:**
- `JustTCG/Features/Decks/DeckBuilderView.swift` — replace dual log sections with single History row
