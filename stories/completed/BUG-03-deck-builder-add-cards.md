# BUG-03 — "Add Cards" Button Doesn't Work in Deck Builder

**Status:** done  
**Area:** M2 — Deck Builder  
**Related stories:** M2-04

## Description

Tapping the "Add Cards" button in `DeckBuilderView` does not open the card picker sheet. The button tap appears to have no effect.

## Steps to Reproduce

1. Open any deck in the Deck Builder
2. Scroll to the "Add Cards" button at the bottom of the list
3. Tap it — `CardPickerView` does not appear

## Likely Cause

The `.sheet(isPresented: $showCardPicker)` modifier is attached to the `List` inside a `ScrollViewReader`. SwiftUI sheet presentation can silently fail when the modifier is on a view that is not in the active view hierarchy or when a parent view hasn't finished loading. The `viewModel` being `nil` on first render means the `Group` returns a `ProgressView`, and the sheet modifier isn't reachable until `viewModel` is set — but by then the state toggle may be ignored.

A secondary possibility: the `Button` inside `Section` inside `List` has its tap area eaten by the list row's own tap gesture or a competing `.onTapGesture` registered on the outer `ScrollViewReader` tree.

## Acceptance Criteria

- [ ] Tapping "Add Cards" reliably opens `CardPickerView` as a sheet
- [ ] The sheet dismisses normally and `viewModel?.loadCards()` is called on dismiss
- [ ] No regression to the rename commit flow (the outer `.onTapGesture` that calls `commitRename` must still work)

## Technical Notes

- View: `JustTCG/Features/Decks/DeckBuilderView.swift`
- The sheet modifier is at line ~61: `.sheet(isPresented: $showCardPicker, onDismiss: { viewModel?.loadCards() })`
- Consider moving the sheet modifier up to the outer `Group` so it is present regardless of `viewModel` load state, or use `.sheet(item:)` pattern keyed on `viewModel`
- `CardPickerView` is at `JustTCG/Features/Decks/CardPickerView.swift`
