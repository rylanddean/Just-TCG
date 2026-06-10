# BUG-31 — Standings View: Replace Table Rows With Polished Cards

**Status:** done  
**Area:** Tournament Detail / Standings

## Description

The standings rows in `TournamentDetailView` use plain `HStack`-based table rows inside a `List`. Like the tournaments list (BUG-30), each placement entry would benefit from being presented as a card: a visually distinct container that surfaces rank, player name, deck archetype, and record at a glance without relying on the eye to parse a wall of uniform grey text.

## Steps to Reproduce

1. Open any tournament
2. Tap the Standings segment

## Observed Behaviour

- Placement rows are thin, dense table rows with no visual grouping or containment
- Rank number, player name, archetype, and record share the same visual weight
- The row has no hover or selection affordance to hint that it is tappable

## Desired Behaviour

Each standing is a card with a clear rank zone on the left and content zone on the right. Top-3 finishers are visually distinct (gold/silver/bronze tint). The card makes it obvious the row is tappable (navigates to the player deck per BUG-28).

## Acceptance Criteria

### PlacementCard component
- [ ] A new `PlacementCard` view replaces the inline `placementRow` builder in `TournamentDetailView`
- [ ] The card uses `RoundedRectangle(cornerRadius: 12)` filled with `Color(.secondarySystemGroupedBackground)`
- [ ] A shadow of `radius: 2, x: 0, y: 1, color: .black.opacity(0.06)` is applied
- [ ] Left zone (fixed width ~52pt): rank number in `.title3.monospacedDigit().weight(.bold)`, coloured by `rankColor` for top 3
- [ ] Top-3 cards receive a left-edge accent strip (2pt wide `RoundedRectangle` in the `rankColor`)
- [ ] Right zone: player name in `.body`, archetype in `.caption .secondary` below; record `W–L–T` in `.caption.monospacedDigit` trailing-aligned

### List integration
- [ ] `.listRowBackground(Color.clear)` and `.listRowSeparator(.hidden)` per row
- [ ] Row insets `EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16)`
- [ ] "Show Top 32 / Show All" expansion button retains its existing behaviour and is styled as a plain text button centred below the cards (not wrapped in a card)

### Swipe actions
- [ ] Swipe-to-favourite still works on `PlacementCard` rows

### No regressions
- [ ] Navigation routing follows BUG-28 (row tap → deck list, not profile)
- [ ] "No decklist" rows are non-tappable and show a muted foreground on the card
- [ ] Meta Share tab is unaffected

## Technical Notes

**Files to change:**
- `JustTCG/Features/Tournaments/TournamentDetailView.swift` — extract `placementRow` into `PlacementCard` struct; apply list row styling
