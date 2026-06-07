import Foundation
import SwiftData
import Observation

@Observable
final class DeckBuilderViewModel {
    let deck: Deck
    private let deckRepo: DeckRepository
    private let cardRepo: CardRepository

    private(set) var cachedCards: [String: CachedCard] = [:]

    private let trainerSubtypes: Set<String> = ["Supporter", "Item", "Stadium", "Tool"]

    var totalCount: Int { deck.cards.reduce(0) { $0 + $1.quantity } }

    var pokemonCards: [DeckCard] {
        sorted(deck.cards.filter {
            guard let c = cachedCards[$0.cardId] else { return false }
            return !c.types.isEmpty
        })
    }

    var trainerCards: [DeckCard] {
        sorted(deck.cards.filter {
            guard let c = cachedCards[$0.cardId] else { return false }
            return c.types.isEmpty && !Set(c.subtypes).isDisjoint(with: trainerSubtypes)
        })
    }

    var energyCards: [DeckCard] {
        sorted(deck.cards.filter {
            guard let c = cachedCards[$0.cardId] else { return false }
            return c.types.isEmpty && Set(c.subtypes).isDisjoint(with: trainerSubtypes)
        })
    }

    init(deck: Deck, modelContext: ModelContext) {
        self.deck = deck
        self.deckRepo = DeckRepository(modelContext: modelContext)
        self.cardRepo = CardRepository(modelContext: modelContext)
    }

    func loadCards() {
        let ids = deck.cards.map { $0.cardId }
        let cards = (try? cardRepo.fetch(ids: ids)) ?? []
        cachedCards = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })
    }

    func rename(to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        deckRepo.renameDeck(deck, to: trimmed)
    }

    func setQuantity(_ quantity: Int, for deckCard: DeckCard) {
        if quantity <= 0 {
            cachedCards.removeValue(forKey: deckCard.cardId)
            deckRepo.removeCard(cardId: deckCard.cardId, from: deck)
        } else {
            deckRepo.setQuantity(quantity, cardId: deckCard.cardId, in: deck)
        }
    }

    private func sorted(_ cards: [DeckCard]) -> [DeckCard] {
        cards.sorted {
            (cachedCards[$0.cardId]?.name ?? $0.cardId) <
            (cachedCards[$1.cardId]?.name ?? $1.cardId)
        }
    }
}
