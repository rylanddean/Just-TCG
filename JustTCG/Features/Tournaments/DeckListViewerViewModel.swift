import Foundation
import SwiftData
import Observation

struct ViewerEntry: Identifiable {
    let id: String
    let entry: LimitlessDeckEntry
    let cachedCard: CachedCard?
}

struct ViewerGroup {
    let title: String
    let entries: [ViewerEntry]
    var total: Int { entries.reduce(0) { $0 + $1.entry.quantity } }
}

@Observable
final class DeckListViewerViewModel {

    private(set) var groups: [ViewerGroup] = []
    private(set) var isLoading = false
    private(set) var error: String? = nil
    private(set) var deckList: LimitlessDeckList? = nil
    private(set) var importedDeck: Deck? = nil

    private let listId: String
    private let client = LimitlessTCGClient()
    private let modelContext: ModelContext

    private static let trainerSubtypes: Set<String> = ["Supporter", "Item", "Stadium", "Tool"]

    init(listId: String, modelContext: ModelContext) {
        self.listId = listId
        self.modelContext = modelContext
    }

    // MARK: - Load

    func load() async {
        guard deckList == nil else { return }
        if let cached = loadFromDisk() {
            deckList = cached
            buildGroups(from: cached)
            return
        }
        await fetch()
    }

    func refresh() async {
        await fetch()
    }

    private func fetch() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let list = try await client.fetchDeckList(listId: listId)
            deckList = list
            saveToDisk(list)
            buildGroups(from: list)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Grouping

    private func buildGroups(from list: LimitlessDeckList) {
        let cardMap = fetchCardMap()

        var pokemon: [ViewerEntry] = []
        var trainer: [ViewerEntry] = []
        var energy:  [ViewerEntry] = []

        for entry in list.entries {
            let card = cardMap["\(entry.setCode.lowercased())-\(entry.number)"]
                    ?? cardMap["\(entry.setCode)-\(entry.number)"]
            let ve = ViewerEntry(id: entry.id, entry: entry, cachedCard: card)
            if let c = card {
                if !c.types.isEmpty {
                    pokemon.append(ve)
                } else if !Set(c.subtypes).isDisjoint(with: Self.trainerSubtypes) {
                    trainer.append(ve)
                } else {
                    energy.append(ve)
                }
            } else {
                // Unknown cards: use name heuristics
                let lower = entry.name.lowercased()
                if lower.contains("energy") {
                    energy.append(ve)
                } else {
                    pokemon.append(ve)
                }
            }
        }

        groups = [
            ViewerGroup(title: "Pokémon", entries: pokemon),
            ViewerGroup(title: "Trainer", entries: trainer),
            ViewerGroup(title: "Energy",  entries: energy),
        ].filter { !$0.entries.isEmpty }
    }

    private func fetchCardMap() -> [String: CachedCard] {
        let descriptor = FetchDescriptor<CachedCard>()
        let cards = (try? modelContext.fetch(descriptor)) ?? []
        var map: [String: CachedCard] = [:]
        for card in cards {
            map[card.id] = card
            map["\(card.setCode.lowercased())-\(card.number)"] = card
        }
        return map
    }

    // MARK: - PTCGL export

    var ptcglExport: String {
        guard let list = deckList else { return "" }
        return list.entries
            .map { "\($0.quantity) \($0.name) \($0.setCode) \($0.number)" }
            .joined(separator: "\n")
    }

    // MARK: - Import to My Decks

    func importDeck(named name: String) {
        let deck = Deck(name: name)
        modelContext.insert(deck)

        let cardMap = fetchCardMap()
        for entry in deckList?.entries ?? [] {
            let cardId = cardMap["\(entry.setCode.lowercased())-\(entry.number)"]?.id
                      ?? "\(entry.setCode)-\(entry.number)"
            let deckCard = DeckCard(cardId: cardId, quantity: entry.quantity)
            modelContext.insert(deckCard)
            deck.cards.append(deckCard)
        }
        deck.updatedAt = .now
        try? modelContext.save()
        importedDeck = deck
    }

    // MARK: - Disk cache

    private static func cacheURL(for listId: String) -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("decklist_\(listId).json")
    }

    private func loadFromDisk() -> LimitlessDeckList? {
        let url = Self.cacheURL(for: listId)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(LimitlessDeckList.self, from: data)
    }

    private func saveToDisk(_ list: LimitlessDeckList) {
        let url = Self.cacheURL(for: listId)
        if let data = try? JSONEncoder().encode(list) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
