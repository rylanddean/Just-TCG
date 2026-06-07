import Foundation
import SwiftData

final class MatchRepository {

    private let context: ModelContext

    init(modelContext: ModelContext) {
        self.context = modelContext
    }

    @discardableResult
    func logMatch(
        deck: Deck,
        archetype: String,
        result: MatchResult,
        format: MatchFormat,
        eventType: EventType,
        notes: String,
        date: Date = .now
    ) -> Match {
        let match = Match(
            date: date,
            opponentArchetype: archetype,
            result: result,
            format: format,
            eventType: eventType,
            notes: notes
        )
        context.insert(match)
        match.deck = deck
        deck.matches.append(match)
        save()
        return match
    }

    func deleteMatch(_ match: Match) {
        context.delete(match)
        save()
    }

    func updateMatch(_ match: Match, notes: String) {
        match.notes = notes
        save()
    }

    private func save() {
        try? context.save()
    }
}
