# BUG-22 — Tournaments View Needs Visual Polish

**Status:** todo  
**Area:** M28 — Tournaments

## Description

`TournamentsView` and its `TournamentRow` subview look assembled rather than designed. The tournament name, date, country, and player count are stacked in a dense `VStack` with uniform caption weights, making it hard to scan. The tier badge is small and undersized for its importance. The filter chip bar has no contextual count or visual separation from the list. The overall impression is rough and unpolished.

## Steps to Reproduce

1. Open the Tournaments tab

## Observed Behaviour

- All metadata (date, country, player count) renders at the same `.caption` weight with identical secondary colour — no visual hierarchy
- Tier badge is a small capsule in the top-right with minimal contrast
- Filter chips sit directly above the first row with no visual separation
- "Last updated X ago" footer row looks like a stray orphan item
- No empty state illustration beyond a generic `ContentUnavailableView`

## Desired Behaviour

The list feels intentional and scan-friendly: the tournament name reads at a glance, the tier badge has clear presence, and metadata is organised into a primary / secondary layer.

## Acceptance Criteria

### TournamentRow
- [ ] Name renders at `.body.weight(.semibold)` with full width (no Spacer between name and tier badge — badge sits to the right on the same baseline)
- [ ] Tier badge is visually prominent: coloured background tinted to tier colour, monospaced bold label, slightly larger padding (`horizontal: 8, vertical: 4`)
- [ ] Date, country, and player count are arranged as a horizontal caption strip below the name, using SF Symbols consistent with the rest of the app — icon + text, no label repetition
- [ ] Row top/bottom padding is increased to `.vertical, 8` for better breathing room
- [ ] A subtle separator line is **not** added — let the default `List` separator do the work

### Filter Bar
- [ ] Filter chip bar is wrapped in a sticky `Section` header (no `listRowBackground(Color.clear)`) so it stays anchored below the nav bar on scroll
- [ ] Each tier chip optionally shows a tournament count in parentheses, e.g. `Regional (14)`, computed from `vm.tournaments`
- [ ] "All" chip count is omitted (showing count for "All" is redundant)

### Footer
- [ ] "Last updated X ago" text is moved to a `listFooter` modifier or styled as a non-tappable footnote row — it should not appear as a selectable `Section` row

### Error / Empty States
- [ ] Error state copy is "Couldn't load tournaments" (lowercase t, matching iOS system copy conventions)
- [ ] No new illustrations required — the existing `ContentUnavailableView` treatment is sufficient once copy is corrected

## Technical Notes

**Files to change:**
- `JustTCG/Features/Tournaments/TournamentsView.swift` — `TournamentRow`, `filterBar`, footer row, error copy
- `JustTCG/Features/Tournaments/TournamentListViewModel.swift` — expose filtered count per tier for chip labels (add `count(for tier: TournamentTier?) -> Int` helper)
