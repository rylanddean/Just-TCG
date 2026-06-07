import Foundation
import SwiftData

final class DeckRepository {

    private let context: ModelContext

    init(modelContext: ModelContext) {
        self.context = modelContext
    }

    // MARK: - Deck operations

    @discardableResult
    func createDeck(name: String) -> Deck {
        let deck = Deck(name: name)
        context.insert(deck)
        save()
        return deck
    }

    func deleteDeck(_ deck: Deck) {
        context.delete(deck)
        save()
    }

    func renameDeck(_ deck: Deck, to name: String) {
        deck.name = name
        touch(deck)
        save()
    }

    // MARK: - Card operations

    // Adds one copy of cardId to the deck. If the card is already present,
    // increments quantity up to 4. Basic-energy cap (60) is enforced in M2-05.
    func addCard(cardId: String, to deck: Deck) {
        if let existing = deck.cards.first(where: { $0.cardId == cardId }) {
            existing.quantity = min(existing.quantity + 1, 4)
        } else {
            let deckCard = DeckCard(cardId: cardId)
            context.insert(deckCard)
            deck.cards.append(deckCard)
        }
        touch(deck)
        save()
    }

    func removeCard(cardId: String, from deck: Deck) {
        guard let deckCard = deck.cards.first(where: { $0.cardId == cardId }) else { return }
        deck.cards.removeAll { $0.cardId == cardId }
        context.delete(deckCard)
        touch(deck)
        save()
    }

    // Sets the quantity of a card already in the deck. quantity must be ≥ 1;
    // to remove a card entirely, use removeCard instead.
    func setQuantity(_ quantity: Int, cardId: String, in deck: Deck) {
        guard quantity >= 1 else { return }
        guard let deckCard = deck.cards.first(where: { $0.cardId == cardId }) else { return }
        deckCard.quantity = quantity
        touch(deck)
        save()
    }

    // MARK: - Private

    private func touch(_ deck: Deck) {
        deck.updatedAt = .now
    }

    private func save() {
        try? context.save()
    }
}
