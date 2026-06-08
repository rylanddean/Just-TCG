# BUG-12 — "In Deck" Badge in Card Picker Is Slow / Doesn't Update After Tapping

**Status:** done  
**Area:** M2 — Deck Builder / Card Picker  
**Related stories:** M2-04, BUG-09, BUG-11

## Description

When the user taps a card row in the "Add Cards" picker sheet, the "N in deck" badge either:

- Does not update at all until the sheet is dismissed and re-opened, or
- Updates with a noticeable lag (multiple frames after the tap)

This makes the interaction feel broken — the user can't tell whether the tap registered.

## Steps to Reproduce

1. Open any deck and tap **Add Cards**
2. Tap a card row that isn't yet in the deck
3. Observe: the "1 in deck" badge does not appear immediately (or appears with visible delay)
4. Dismiss the sheet and re-open — the count is now correct

## Root Cause

`CardPickerView` receives the deck as `let deck: Deck` — a plain stored property, not `@Bindable var deck`. SwiftUI's `@Observable` access tracking instruments reads that happen during `body` evaluation, but the sheet environment creates a boundary that can weaken or break the observation link for a non-`@Bindable` let property. As a result, mutations to `deck.cards` made by `DeckRepository.addCard(...)` do not reliably trigger a re-render of `CardPickerView.body`.

`deckQuantity(for:)` and `isAtMax(_:)` both read `deck.cards` and pass their results down to `CardPickerRow` as plain `Int`/`Bool` values. If the parent view is not re-rendered after the mutation, those values stay stale.

## Fix

Two complementary changes:

1. **Declare `deck` as `@Bindable`** in `CardPickerView` (`@Bindable var deck: Deck`) so SwiftUI properly tracks mutations to `deck.cards` through the sheet boundary.
2. **Optimistic local state** (belt-and-suspenders): maintain a `@State private var pendingCounts: [String: Int] = [:]` dictionary that is updated synchronously on tap before `DeckRepository` is called. `deckQuantity(for:)` merges `pendingCounts` with `deck.cards` so the badge updates immediately even if the observation re-render is slightly deferred.

## Acceptance Criteria

- [x] Tapping a card row immediately shows or increments the "in deck" badge with no visible delay
- [x] The badge reflects the true count after each tap (not batched or debounced)
- [x] No regression: the count stays correct if the user taps the same card multiple times in succession
- [x] No regression: `isAtMax` greys out the row correctly once the cap is reached

## Technical Notes

- File to change: `JustTCG/Features/Decks/CardPickerView.swift`
- `DeckBuilderView` passes `CardPickerView(deck: deck)` — the call site passes a `@Model` object, so changing the declaration to `@Bindable var deck` is non-breaking
- `pendingCounts` can be cleared when the sheet is dismissed (already handled by `DeckBuilderView.onDismiss`) — no persistence needed
