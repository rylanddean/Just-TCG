# BUG-28 — Standings Row Navigation Goes to Wrong Destination

**Status:** done  
**Area:** Tournament Detail / Standings

## Description

In `TournamentDetailView`, tapping a player row in the standings navigates directly to `PlayerDetailView`. The intended UX is: tapping a standings row opens that player's **tournament deck list** (`DeckListViewerView`), with a "View Profile" affordance within that view to navigate to `PlayerDetailView`. Currently the deck list is only reachable via a small `list.bullet` icon on the right, which is easy to miss. Tapping the player name goes to their profile, then pressing Back brings you to their profile again if you got there via the icon — the back-stack order is wrong.

## Steps to Reproduce

1. Open any tournament in the Tournaments tab
2. Tap the Standings segment
3. Tap a player name in the standings list

## Observed Behaviour

- Tapping the player name navigates to `PlayerDetailView`
- Tapping the `list.bullet` icon navigates to `DeckListViewerView`
- Back from `DeckListViewerView` returns to standings correctly
- Back from `PlayerDetailView` (reached via player name) also returns to standings — but the correct path should be standings → deck → profile, not standings → profile directly

## Desired Behaviour

- Tapping anywhere on a standings row navigates to `DeckListViewerView` (the player's tournament deck)
- `DeckListViewerView` shows a "View Profile" button/chip at the top that pushes `PlayerDetailView` onto the stack
- The back stack is: Standings → DeckListViewerView → PlayerDetailView

## Acceptance Criteria

### Standings row
- [ ] The entire `placementRow` is wrapped in a single `NavigationLink` to `DeckListViewerView(listId:, archetype:)` when `p.hasDeckList` is true
- [ ] When `p.hasDeckList` is false, the row is not tappable (no `NavigationLink`); player name is plain `Text`
- [ ] The standalone `list.bullet` `NavigationLink` icon is **removed** — it is replaced by the row-level link above
- [ ] The `NavigationLink` wrapping `PlayerDetailView` directly from the player name is **removed**

### DeckListViewerView — profile entry point
- [ ] `DeckListViewerView` gains an optional `playerId: String?` parameter
- [ ] When `playerId` is non-nil, a "Player Profile" `NavigationLink` button is added to the toolbar (`.navigationBarItems(trailing:)`) that pushes `PlayerDetailView(playerID: playerId)`
- [ ] When `playerId` is nil, no profile button is shown (backwards-compatible)

### No regressions
- [ ] Swipe-to-favourite on standings rows still works
- [ ] Rank colour coding (`rankColor`) is unchanged
- [ ] Rows for players without a deck list still display "No decklist" copy
- [ ] `PlayerDetailView` and `DeckListViewerView` themselves are otherwise unchanged

## Technical Notes

**Files to change:**
- `JustTCG/Features/Tournaments/TournamentDetailView.swift` — `placementRow`: replace two `NavigationLink`s with single row-level link to deck; pass `playerId` to `DeckListViewerView`
- `JustTCG/Features/Players/DeckListViewerView.swift` (or equivalent file) — add optional `playerId` param + toolbar profile link
