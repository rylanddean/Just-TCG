# BUG-10 — Deck Builder Stepper Allows More Than 4 Copies

**Status:** done  
**Area:** M2 — Deck Builder  
**Related stories:** M2-04, M2-05, BUG-06

## Description

Tapping the `+` stepper button on a card row in `DeckBuilderView` past 4 copies silently saves `quantity = 5, 6, …` to SwiftData. The validation banner shows an error, but the write is not blocked. Basic Energy cards have the same problem — their 60-copy cap is also unenforced through this path.

## Steps to Reproduce

1. Open any deck in the Deck Builder that has a non-Basic-Energy card with 4 copies
2. Tap the `+` stepper button on that card row
3. Observe: the count ticks up to 5, the validation banner shows an error, but the data is persisted with `quantity = 5`

## Root Cause

`DeckBuilderViewModel.setQuantity(_:for:)` passes `quantity` straight to `DeckRepository.setQuantity(_:cardId:in:)`, which writes the value without any cap:

```swift
func setQuantity(_ quantity: Int, for deckCard: DeckCard) {
    if quantity <= 0 { ... }
    else {
        deckRepo.setQuantity(quantity, cardId: ..., in: deck)  // no cap!
    }
}
```

`DeckRepository.addCard` correctly caps at 4 (or 60 for Basic Energy) using `isBasicEnergy`, but `setQuantity` is a separate code path used exclusively by the stepper and has no equivalent guard.

## Fix

Clamp `quantity` to the card's legal maximum inside `DeckBuilderViewModel.setQuantity` before delegating to the repo. The cached card is already in `cachedCards` at that point, so `isBasicEnergy` is available.

## Acceptance Criteria

- [x] Tapping `+` when a non-Basic-Energy card is at 4 copies leaves the count at 4
- [x] Tapping `+` when a Basic Energy card is at 60 leaves the count at 60
- [x] Tapping `−` to 0 still removes the card
- [x] No regression to the `addCard` path (CardPicker → deck)

## Technical Notes

- Fix: `JustTCG/Features/Decks/DeckBuilderViewModel.swift` — `setQuantity(_:for:)`
- Cap logic: `let cap = isBasicEnergy ? 60 : 4` — same as `DeckRepository.addCard`
- `cachedCards[deckCard.cardId]?.isBasicEnergy` may be nil if card not yet loaded; default to `false` (non-energy cap) which is the safer choice
