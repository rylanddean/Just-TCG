# M10-03 — Import Deck Sheet

**Status:** done  
**Milestone:** M10 — Deck Import  
**Dependencies:** M10-02

## Acceptance Criteria

- [x] "Import" toolbar button (`arrow.down.doc`) in `DecksView` navigation bar alongside "+"
- [x] Tapping "Import" opens `ImportDeckSheet` as `.sheet`
- [x] On appear (`.task`), sheet reads clipboard and runs parse + lookup; empty clipboard → empty state
- [x] Sheet displays: deck name `TextField`, summary line (`X matched · Y unmatched`), scrollable list of all entries with quantity badge, card name + set/number, and match status icon (green checkmark / yellow warning)
- [x] "Import Deck" button disabled when matched count is 0; on tap creates `Deck` + `DeckCard`s for matched entries, saves, dismisses
- [x] Unmatched entries shown but not imported
- [x] "Cancel" button dismisses without creating anything
- [x] Newly imported deck appears at top of `DecksView` via existing `updatedAt` sort

## Technical Notes

- `JustTCG/Features/Decks/ImportDeckSheet.swift`
- `DecksView` uses `ToolbarItemGroup` for both Import and + buttons
