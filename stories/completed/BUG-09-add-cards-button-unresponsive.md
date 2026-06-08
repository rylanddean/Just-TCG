# BUG-09 — "Add Cards" Button Still Unresponsive in Deck Builder

**Status:** done  
**Area:** M2 — Deck Builder  
**Related stories:** M2-04, BUG-03

## Description

Tapping the "Add Cards" button in `DeckBuilderView` does nothing. `CardPickerView` never appears. The button renders correctly but the tap is silently swallowed.

BUG-03 previously fixed a related sheet-placement issue (moved `.sheet` to the outer `Group`). This is a separate, subsequent regression.

## Steps to Reproduce

1. Open any deck in the Deck Builder
2. Scroll to the "Add Cards" button at the bottom of the list
3. Tap it — `CardPickerView` does not appear

## Root Cause

`builderList(vm:)` applies `.onTapGesture` directly to the `List`:

```swift
.onTapGesture {
    if isRenaming { commitRename(vm: vm) }
}
```

In SwiftUI, a `.onTapGesture` on a parent container installs a gesture recognizer that consumes every tap event on that view — even when the closure body is a no-op. This prevents the "Add Cards" `Button` (and any other interactive control inside the `List`) from receiving the tap.

The dismiss behaviour this gesture was guarding is already covered by `@FocusState` and the existing `onChange(of: renameFocused)` handler, which commits the rename whenever the text field loses focus — including when the user taps elsewhere in the list.

## Fix

Remove the `.onTapGesture` from the `List` in `builderList(vm:)`. No other change is needed.

## Acceptance Criteria

- [x] Tapping "Add Cards" reliably opens `CardPickerView` as a sheet
- [x] Tapping away from the rename text field still commits the rename (via `onChange(of: renameFocused)`)
- [x] No regression to quantity stepper buttons (`+` / `−`) in card rows

## Technical Notes

- File: `JustTCG/Features/Decks/DeckBuilderView.swift`
- Offending lines: `.onTapGesture { if isRenaming { commitRename(vm: vm) } }` inside `builderList(vm:)`
- Rename dismiss is handled by `onChange(of: renameFocused) { _, focused in if !focused { commitRename(vm: vm) } }` — no replacement gesture needed
