# BUG-13 — Card Picker Has No Way to Decrease Count After Adding a Card

**Status:** done  
**Area:** M2 — Deck Builder / Card Picker  
**Related stories:** M2-04, BUG-12

## Description

Once a card has been added to the deck via the picker, the "N in deck" badge is display-only. The user has no way to decrease (or further increase) the count without dismissing the picker and using the stepper in `DeckBuilderView`. This is especially painful when they accidentally add too many copies.

The expected UX is: once a card is in the deck, the badge is replaced by inline **−** / **+** stepper buttons so the user can manage the count without leaving the picker.

## Steps to Reproduce

1. Open any deck and tap **Add Cards**
2. Tap a card row — the "1 in deck" badge appears
3. Try to decrease the count back to 0 while staying in the picker — there is no control to do so

## Desired Behaviour

When `deckQuantity(for: card) > 0`, the trailing area of `CardPickerRow` shows:

```
[ − ]  2 in deck  [ + ]
```

- **−** decrements the count; if it would reach 0, the card is removed from the deck entirely
- **+** increments the count up to the same cap enforced by `isAtMax`
- Both buttons update the badge immediately (see BUG-12 for the reactivity fix)
- The existing "tap whole row to add" gesture is removed once the card is in the deck (tapping the row when `deckQuantity == 0` still adds the first copy)

## Fix

1. Add an `onRemove: () -> Void` callback to `CardPickerRow` alongside the existing `onTap`
2. In the trailing `if deckQuantity > 0` block, replace the text badge with an `HStack` containing a **−** `Button`, the count label, and a **+** `Button`
3. Wire `onRemove` in `CardPickerView` to call `DeckRepository.removeCard` (when qty would drop to 0) or `DeckRepository.setQuantity(qty - 1, ...)` (when qty > 1)
4. Apply the BUG-12 fix first (or in the same PR) so both buttons reflect their effect immediately

## Acceptance Criteria

- [x] Cards not yet in the deck show the tap-to-add row affordance (unchanged)
- [x] Cards already in the deck show `[ − ]  N in deck  [ + ]` in the trailing area
- [x] Tapping **+** increments the count; row greys out when the cap is reached and **+** is disabled
- [x] Tapping **−** decrements the count; at 1 copy, tapping **−** removes the card from the deck and returns the row to its tap-to-add state
- [x] Both buttons respond immediately with no visible lag (requires BUG-12 fix)
- [x] No regression: long-press to view card detail still works

## Technical Notes

- File to change: `JustTCG/Features/Decks/CardPickerView.swift`
- `DeckRepository` already has `removeCard(cardId:from:)` and `setQuantity(_:cardId:in:)` — no new repository methods needed
- `CardPickerRow` becomes `CardPickerRow(card:deckQuantity:isAtMax:onAdd:onDecrement:onLongPress:)` — rename `onTap` → `onAdd` for clarity
- `onAdd` is still called for the whole-row tap when `deckQuantity == 0`; when `deckQuantity > 0`, the row tap is a no-op and only the stepper buttons are active
