# M2-01 — Deck & DeckCard SwiftData Models

**Status:** todo  
**Milestone:** M2 — Deck Builder  
**Dependencies:** M0

## User Story
As a developer, I need `Deck` and `DeckCard` SwiftData models with iCloud sync enabled so that user decks persist locally and sync across devices.

## Acceptance Criteria

- [ ] `Deck` `@Model` class in `Data/Models/Deck.swift`:
  - `id: UUID`, `name: String`, `format: String` (default: `"Standard"`), `createdAt: Date`, `updatedAt: Date`
  - `@Relationship(deleteRule: .cascade) var cards: [DeckCard]`
  - `@Relationship(deleteRule: .cascade) var matches: [Match]` (stub — Match model added in M3)
- [ ] `DeckCard` `@Model` class in `Data/Models/DeckCard.swift`:
  - `cardId: String` (Limitless card ID), `quantity: Int`, `deck: Deck?`
- [ ] Both models registered in the CloudKit-backed `ModelConfiguration`
- [ ] `DeckRepository` in `Data/Repositories/DeckRepository.swift` exposes:
  - `func createDeck(name: String) -> Deck`
  - `func deleteDeck(_ deck: Deck)`
  - `func renameDeck(_ deck: Deck, to name: String)`
  - `func addCard(cardId: String, to deck: Deck)`
  - `func removeCard(cardId: String, from deck: Deck)`
  - `func setQuantity(_ quantity: Int, cardId: String, in deck: Deck)`
- [ ] `updatedAt` is updated on every `DeckRepository` write operation

## Technical Notes

- `DeckCard.quantity` must be ≥ 1 — enforce in `setQuantity`, not at the model level
- When `addCard` is called for a card already in the deck, increment quantity (up to 4, or 60 for basic Energy — basic Energy check deferred to legality validator in M2-05)
- `DeckRepository` takes a `ModelContext` in its initialiser
