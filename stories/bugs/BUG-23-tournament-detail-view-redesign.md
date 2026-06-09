# BUG-23 — Tournament Detail View Needs Visual Polish

**Status:** todo  
**Area:** M28 — Tournament Detail

## Description

`TournamentDetailView` feels unfinished. The header is a plain `HStack` of text labels. The standings rows are dense and uniform with no visual hierarchy between top finishers and the rest of the field. The Meta Share tab is addressed separately in BUG-20; this bug covers the header, standings tab, and overall detail polish.

## Steps to Reproduce

1. Open any tournament from the Tournaments tab

## Observed Behaviour

- Header: date and country sit left, player count sits right — functional but bare with no visual weight or separation from the list content below
- Standings: `#1`, `#2`, `#3` rank numbers use `.yellow`, grey, and brown colour respectively, but rows are otherwise identical — no size difference, no trophy icon, no podium distinction
- Win–loss–tie record is caption-sized secondary text with no framing
- "No decklist" label appears in the trailing column for every player without a list — for large tournaments this creates visual noise
- The "Show Top 32 / Show All" pagination button is a plain centered text button with no visual affordance
- Segment picker sits inside a `List` row which gives it insets that fight the full-width segmented control

## Desired Behaviour

The header reads as a proper title area. Top finishers stand out from the field. Players without decklists don't create noise. The segment picker sits cleanly at the top.

## Acceptance Criteria

### Header
- [ ] Header is rendered outside the `List` as a `VStack` pinned below the navigation bar, or styled as a visually distinct `listRowBackground`-coloured section
- [ ] Tournament name is already in `.navigationTitle` — the header focuses on: date (formatted as "June 7, 2026"), location (country + flag emoji if available), player count with a `person.2.fill` icon, and tier badge matching the style in BUG-22
- [ ] A subtle divider or `listSectionSpacing` separates the header from the segment picker

### Segment Picker
- [ ] The `Picker(.segmented)` is rendered in a `listRowInsets`-free row (`.listRowInsets(EdgeInsets())`) so it touches the full List width
- [ ] `listRowSeparator(.hidden)` on the picker row

### Standings Rows
- [ ] Ranks #1, #2, #3 are visually distinguished:
  - `#1`: trophy `SF Symbol` (`trophy.fill`) in gold, `.title3` rank number
  - `#2`: silver dot or medal icon, `.subheadline` rank number  
  - `#3`: bronze treatment, `.subheadline` rank number
  - All others: `.caption.monospacedDigit()` secondary rank
- [ ] Win–loss–tie record is formatted as a pill or mono-spaced badge (`W–L–T`) rather than plain secondary text
- [ ] Rows without a deck list omit the "No decklist" label entirely — the absence of a deck list icon is sufficient indication
- [ ] Archetype name below player name uses `.caption` with a coloured dot matching the archetype (or simply secondary colour)

### Pagination
- [ ] "Show Top 32" / "Show All" button is styled as a rounded bordered button (`.buttonStyle(.bordered)`) rather than a plain text link

### No Regressions
- [ ] NavigationLink to `PlayerDetailView` from player name still works
- [ ] NavigationLink to `DeckListViewerView` from the deck list icon still works
- [ ] Leading swipe-to-favourite action on placement rows still works

## Technical Notes

**Files to change:**
- `JustTCG/Features/Tournaments/TournamentDetailView.swift` — header layout, `placementRow`, pagination button, segment picker row insets
- No view model changes required
