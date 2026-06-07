import Foundation
import SwiftData
import Observation

@Observable
final class DeckBuilderViewModel {
    let deck: Deck
    private let deckRepo: DeckRepository
    private let cardRepo: CardRepository

    private(set) var cachedCards: [String: CachedCard] = [:]
    private(set) var validationErrors: [DeckValidationError] = []

    var totalCount: Int { deck.cards.reduce(0) { $0 + $1.quantity } }

    private var groups: DeckGrouper.Groups { DeckGrouper.group(deck.cards, cardMap: cachedCards) }

    var pokemonCards: [DeckCard] { groups.pokemon }
    var trainerCards: [DeckCard] { groups.trainer }
    var energyCards:  [DeckCard] { groups.energy }

    var exportString: String { DeckExporter.export(deck, cards: Array(cachedCards.values)) }

    init(deck: Deck, modelContext: ModelContext) {
        self.deck = deck
        self.deckRepo = DeckRepository(modelContext: modelContext)
        self.cardRepo = CardRepository(modelContext: modelContext)
    }

    func loadCards() {
        let ids = deck.cards.map { $0.cardId }
        let cards = (try? cardRepo.fetch(ids: ids)) ?? []
        cachedCards = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })
        revalidate()
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
        revalidate()
    }

    func cardIds(forName name: String) -> [String] {
        deck.cards
            .filter { cachedCards[$0.cardId]?.name == name }
            .map { $0.cardId }
    }

    private func revalidate() {
        validationErrors = DeckValidator.validate(deck, cards: Array(cachedCards.values))
    }
}
