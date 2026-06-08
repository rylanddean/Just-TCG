# M16-02 — Auto-Record Edits in DeckRepository

**Status:** done  
**Milestone:** M16 — Deck Edit Log  
**Dependencies:** M16-01

## User Story

As a player, I want deck edits to be captured automatically every time I add, remove, or change a card (or rename the deck) so that I don't have to do anything extra to build up the history.

## Acceptance Criteria

- [x] `DeckRepository.addCard` creates and inserts a `DeckEdit` entry with `kind: .addCard`, the correct `cardId`, `cardName`, `quantityBefore` (0 if new card, existing qty if already present and incremented), and `quantityAfter`
- [x] `DeckRepository.removeCard` creates a `DeckEdit` entry with `kind: .removeCard` and `quantityBefore` set to the card's quantity at the time of removal, `quantityAfter: 0`
- [x] `DeckRepository.setQuantity` creates a `DeckEdit` entry with `kind: .setQuantity` and the correct before/after quantities; no entry is created if the quantity is unchanged
- [x] `DeckRepository.renameDeck` creates a `DeckEdit` entry with `kind: .rename`, `nameBefore` set to the deck's current name, and `nameAfter` set to the new name; no entry is created if the name is unchanged
- [x] All new `DeckEdit` entries are inserted into the model context and appended to `deck.edits`
- [x] `cardName` is passed into `addCard`, `removeCard`, and `setQuantity` as an optional parameter (`cardName: String? = nil`) so callers can supply the human-readable name without forcing a card lookup inside the repository

## Technical Notes

`DeckRepository` is a plain Swift class with no card-lookup capability — it takes `cardId` strings, not `CachedCard` objects. The `cardName` parameter keeps the repository dependency-free. Callers that have access to a `CachedCard` (e.g. `DeckBuilderViewModel`) should pass `card.name`; callers that don't (e.g. `ImportDeckSheet` bulk-add) can pass `nil` and the name will be left blank in the log.

Example signature change for `addCard`:
```swift
func addCard(cardId: String, to deck: Deck, isBasicEnergy: Bool = false, cardName: String? = nil)
```

The edit helper is a private method to avoid repetition:
```swift
private func recordEdit(_ edit: DeckEdit, for deck: Deck) {
    context.insert(edit)
    deck.edits.append(edit)
}
```
