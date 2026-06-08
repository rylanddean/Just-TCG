import Foundation
import SwiftData

final class DeckRepository {

    private let context: ModelContext
    private var saveTask: Task<Void, Never>?

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

    func setStatus(_ status: DeckStatus, for deck: Deck) {
        deck.status = status
        touch(deck)
        save()
    }

    func renameDeck(_ deck: Deck, to name: String) {
        guard name != deck.name else { return }
        let before = deck.name
        deck.name = name
        touch(deck)
        recordEdit(DeckEdit(kind: .rename, nameBefore: before, nameAfter: name), for: deck)
        save()
    }

    // MARK: - Card operations

    // Adds one copy of cardId to the deck. If the card is already present,
    // increments quantity up to 4 (or 60 for basic Energy).
    func addCard(cardId: String, to deck: Deck, isBasicEnergy: Bool = false, cardName: String? = nil) {
        let before: Int
        if let existing = deck.cards.first(where: { $0.cardId == cardId }) {
            before = existing.quantity
            let cap = isBasicEnergy ? 60 : 4
            existing.quantity = min(existing.quantity + 1, cap)
        } else {
            before = 0
            let deckCard = DeckCard(cardId: cardId)
            context.insert(deckCard)
            deck.cards.append(deckCard)
        }
        let after = deck.cards.first(where: { $0.cardId == cardId })?.quantity ?? 1
        touch(deck)
        recordEdit(DeckEdit(kind: .addCard, cardId: cardId, cardName: cardName,
                            quantityBefore: before, quantityAfter: after), for: deck)
        save()
    }

    func removeCard(cardId: String, from deck: Deck, cardName: String? = nil) {
        guard let deckCard = deck.cards.first(where: { $0.cardId == cardId }) else { return }
        let before = deckCard.quantity
        deck.cards.removeAll { $0.cardId == cardId }
        context.delete(deckCard)
        touch(deck)
        recordEdit(DeckEdit(kind: .removeCard, cardId: cardId, cardName: cardName,
                            quantityBefore: before, quantityAfter: 0), for: deck)
        save()
    }

    // Sets the quantity of a card already in the deck. quantity must be ≥ 1;
    // to remove a card entirely, use removeCard instead.
    func setQuantity(_ quantity: Int, cardId: String, in deck: Deck, cardName: String? = nil) {
        guard quantity >= 1 else { return }
        guard let deckCard = deck.cards.first(where: { $0.cardId == cardId }) else { return }
        let before = deckCard.quantity
        guard quantity != before else { return }
        deckCard.quantity = quantity
        touch(deck)
        recordEdit(DeckEdit(kind: .setQuantity, cardId: cardId, cardName: cardName,
                            quantityBefore: before, quantityAfter: quantity), for: deck)
        save()
    }

    // MARK: - Private

    private func recordEdit(_ edit: DeckEdit, for deck: Deck) {
        context.insert(edit)
        deck.edits.append(edit)
    }

    private func touch(_ deck: Deck) {
        deck.updatedAt = .now
    }

    // Rapid taps (e.g. deck builder +/-) update the in-memory model immediately;
    // the actual disk write is coalesced so repeated taps don't queue up on the main thread.
    private func save() {
        saveTask?.cancel()
        saveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, let self else { return }
            try? self.context.save()
        }
    }

    func saveNow() {
        saveTask?.cancel()
        saveTask = nil
        try? context.save()
    }
}
