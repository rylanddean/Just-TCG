# M16-01 — DeckEdit SwiftData Model

**Status:** done  
**Milestone:** M16 — Deck Edit Log  
**Dependencies:** none

## User Story

As a player, I want every card change I make to a deck to be recorded so that I can look back and see exactly how the deck evolved over time.

## Acceptance Criteria

- [x] A new `DeckEdit` SwiftData model is added with the following stored properties:
  - `id: UUID`
  - `date: Date`
  - `kind: DeckEditKind` (see enum below)
  - `cardId: String?` — nil for rename edits
  - `cardName: String?` — human-readable name, snapshotted at edit time; nil for rename edits
  - `quantityBefore: Int` — 0 for addCard; previous quantity for removeCard/setQuantity
  - `quantityAfter: Int` — new quantity for addCard/setQuantity; 0 for removeCard
  - `nameBefore: String?` — previous deck name, populated only for rename edits
  - `nameAfter: String?` — new deck name, populated only for rename edits
  - `deck: Deck?` — inverse relationship
- [x] `DeckEditKind` is a `String`-backed `Codable` enum with cases: `addCard`, `removeCard`, `setQuantity`, `rename`
- [x] `Deck` gains a new relationship: `@Relationship(deleteRule: .cascade) var edits: [DeckEdit] = []`
- [x] `DeckEdit` is registered in the SwiftData schema in `JustTCGApp.swift`

## Technical Notes

**New file:** `JustTCG/Data/Models/DeckEdit.swift`

```swift
enum DeckEditKind: String, Codable {
    case addCard, removeCard, setQuantity, rename
}

@Model
final class DeckEdit {
    var id: UUID
    var date: Date
    var kind: DeckEditKind
    var cardId: String?
    var cardName: String?
    var quantityBefore: Int
    var quantityAfter: Int
    var nameBefore: String?
    var nameAfter: String?
    var deck: Deck?

    init(
        date: Date = .now,
        kind: DeckEditKind,
        cardId: String? = nil,
        cardName: String? = nil,
        quantityBefore: Int = 0,
        quantityAfter: Int = 0,
        nameBefore: String? = nil,
        nameAfter: String? = nil
    ) { ... }
}
```

`cardName` should be snapshotted at edit time (passed in from the caller), since card names don't change but the card might theoretically be removed from the cache in a future data migration.

Add `DeckEdit.self` to the `Schema([...])` array in `JustTCGApp.swift`. No seed-key bump needed — this is an additive model (no changes to `CachedCard`).
