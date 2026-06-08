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
    private(set) var basicEnergyIndex: [String: CachedCard] = [:]

    var totalCount: Int { deck.cards.reduce(0) { $0 + $1.quantity } }

    private var groups: DeckGrouper.Groups { DeckGrouper.group(deck.cards, cardMap: cachedCards) }

    var pokemonCards:   [DeckCard] { groups.pokemon }
    var supporterCards: [DeckCard] { groups.trainerGroups.supporter }
    var itemCards:      [DeckCard] { groups.trainerGroups.item }
    var toolCards:      [DeckCard] { groups.trainerGroups.tool }
    var stadiumCards:   [DeckCard] { groups.trainerGroups.stadium }
    var aceSpecCards:   [DeckCard] { groups.trainerGroups.aceSpec }
    var energyCards:    [DeckCard] { groups.energy }

    var exportString: String { DeckExporter.export(deck, cards: Array(cachedCards.values)) }

    static let basicEnergyTypeNames = [
        "Fire", "Water", "Grass", "Lightning", "Fighting",
        "Psychic", "Darkness", "Metal", "Colorless"
    ]

    var basicEnergyTypes: [(typeName: String, card: CachedCard)] {
        Self.basicEnergyTypeNames.compactMap { t in
            basicEnergyIndex[t].map { (typeName: t, card: $0) }
        }
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
        loadBasicEnergyIndex()
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
            let isBasicEnergy = cachedCards[deckCard.cardId]?.isBasicEnergy ?? false
            let cap = isBasicEnergy ? 60 : 4
            deckRepo.setQuantity(min(quantity, cap), cardId: deckCard.cardId, in: deck)
        }
        revalidate()
    }

    func quickAddBasicEnergy(card: CachedCard) {
        if let existing = deck.cards.first(where: { $0.cardId == card.id }) {
            deckRepo.setQuantity(existing.quantity + 1, cardId: card.id, in: deck)
        } else {
            deckRepo.addCard(cardId: card.id, to: deck, isBasicEnergy: true)
            cachedCards[card.id] = card
        }
        revalidate()
    }

    func cardIds(forName name: String) -> [String] {
        deck.cards
            .filter { cachedCards[$0.cardId]?.name == name }
            .map { $0.cardId }
    }

    private func loadBasicEnergyIndex() {
        let allEnergies = (try? cardRepo.fetchBasicEnergies()) ?? []
        var index: [String: CachedCard] = [:]
        for typeName in Self.basicEnergyTypeNames {
            let cardName = "\(typeName) Energy"
            let best = allEnergies
                .filter { $0.name == cardName }
                .max { ($0.setReleaseDate ?? .distantPast) < ($1.setReleaseDate ?? .distantPast) }
            if let best { index[typeName] = best }
        }
        basicEnergyIndex = index
    }

    private func revalidate() {
        validationErrors = DeckValidator.validate(deck, cards: Array(cachedCards.values))
    }
}
