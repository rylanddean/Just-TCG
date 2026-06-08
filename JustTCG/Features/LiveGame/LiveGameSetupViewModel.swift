import Foundation
import SwiftData
import Observation

enum GoesFirst {
    case me, them, undecided
}

@Observable
final class LiveGameSetupViewModel {
    var archetypeQuery: String = "" {
        didSet { if oldValue != archetypeQuery { suppressSuggestions = false } }
    }
    private(set) var suppressSuggestions = false

    var goesFirst: GoesFirst = .undecided
    var eventType: EventType = .casual
    var format: MatchFormat = .bo3
    var showMoreDetails = false
    var quickPickSelection: String = "Custom"

    var isValid: Bool { !archetypeQuery.trimmingCharacters(in: .whitespaces).isEmpty }

    var suggestions: [Archetype] {
        guard !archetypeQuery.isEmpty, !suppressSuggestions else { return [] }
        return ArchetypeRepository.shared.search(query: archetypeQuery)
    }

    var metaDecks: [String] {
        ArchetypeRepository.shared.metaOrdered.map(\.name)
    }

    func selectArchetype(_ archetype: Archetype) {
        archetypeQuery = archetype.name
        suppressSuggestions = true
        quickPickSelection = "Custom"
    }

    func startGame(deck: Deck, context: ModelContext) -> LiveGame {
        let repo = LiveGameRepository(modelContext: context)
        let game = repo.startGame(
            deck: deck,
            opponentArchetype: archetypeQuery.trimmingCharacters(in: .whitespaces),
            eventType: eventType,
            format: format,
            isPlayerGoingFirst: goesFirst == .me
        )
        if goesFirst != .undecided {
            repo.startTurn(game: game, isPlayerTurn: goesFirst == .me)
        }
        return game
    }
}
