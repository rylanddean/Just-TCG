# BUG-30 — Tournaments List: Replace Table Rows With Polished Cards

**Status:** done  
**Area:** Tournaments

## Description

`TournamentsView` uses a plain `List` with `TournamentRow` subviews that look like standard table rows. BUG-22 improved the visual hierarchy within the row, but the fundamental presentation — borderless rows inside a `List` — still feels utilitarian. Replacing the row with a card-style component (rounded rectangle background, subtle shadow, full-bleed padding) makes the list feel like a curated feed rather than a data dump.

**Note:** BUG-22 addressed typography and badge sizing. This story is about the row's outer container and layout structure becoming a card.

## Steps to Reproduce

1. Open the Tournaments tab

## Observed Behaviour

- Rows are standard `List` rows with a system separator and no visual containment
- The tier badge and metadata feel unanchored within the full-width row

## Desired Behaviour

Each tournament is presented as a visually distinct card — rounded, lightly shadowed, with clear internal zones for the name, tier badge, and metadata strip.

## Acceptance Criteria

### TournamentCard component
- [ ] A new `TournamentCard` view replaces `TournamentRow` in `TournamentsView`
- [ ] The card uses a `RoundedRectangle(cornerRadius: 12)` filled with `Color(.secondarySystemGroupedBackground)` as its background
- [ ] A shadow of `radius: 2, x: 0, y: 1, color: .black.opacity(0.06)` is applied to the card
- [ ] Internal layout: tournament name (`.body.weight(.semibold)`) on the top line; tier badge inline to the right; second line shows date + country + player count as a caption strip with SF Symbol icons

### List integration
- [ ] `TournamentsView` uses `.listStyle(.plain)` (or switches to `LazyVStack` in a `ScrollView`) with `.listRowBackground(Color.clear)` and `.listRowSeparator(.hidden)` per row
- [ ] Row insets are `EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16)` to give cards a consistent gap

### Tier badge
- [ ] Tier badge background colour is derived from the tier: e.g. Regional → `.blue`, International → `.purple`, World → `.yellow`; Challenge/Cup → `.gray`
- [ ] Badge uses `.caption.weight(.bold)` with `.white` foreground and `horizontal: 8, vertical: 3` padding

### Filter bar & footer
- [ ] Existing filter chip bar and "Last updated" footer from BUG-22 are preserved
- [ ] Empty and error states are unchanged

## Technical Notes

**Files to change:**
- `JustTCG/Features/Tournaments/TournamentsView.swift` — replace `TournamentRow` with `TournamentCard`; adjust list style and row insets
