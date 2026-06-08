import Foundation
import SwiftData

final class LiveGameRepository {

    private let context: ModelContext

    init(modelContext: ModelContext) {
        self.context = modelContext
    }

    @discardableResult
    func startGame(
        deck: Deck,
        opponentArchetype: String,
        eventType: EventType,
        format: MatchFormat,
        isPlayerGoingFirst: Bool
    ) -> LiveGame {
        let game = LiveGame(
            opponentArchetype: opponentArchetype,
            eventType: eventType,
            format: format,
            isPlayerGoingFirst: isPlayerGoingFirst
        )
        game.deck = deck
        context.insert(game)
        save()
        return game
    }

    @discardableResult
    func startTurn(game: LiveGame, isPlayerTurn: Bool) -> GameTurn {
        // Close the currently active turn, if any
        if let active = game.turns.first(where: { $0.endedAt == nil }) {
            active.endedAt = .now
        }
        let turn = GameTurn(
            turnNumber: (game.turns.map(\.turnNumber).max() ?? 0) + 1,
            isPlayerTurn: isPlayerTurn,
            playerPrizesAtStart: game.playerPrizesRemaining,
            opponentPrizesAtStart: game.opponentPrizesRemaining
        )
        context.insert(turn)
        turn.game = game
        game.turns.append(turn)
        save()
        return turn
    }

    func recordPrizeTaken(game: LiveGame, byPlayer: Bool) {
        if byPlayer {
            game.playerPrizesRemaining = max(0, game.playerPrizesRemaining - 1)
        } else {
            game.opponentPrizesRemaining = max(0, game.opponentPrizesRemaining - 1)
        }
        if let active = game.turns.first(where: { $0.endedAt == nil }) {
            active.prizesTaken += 1
        }
        save()
    }

    func reversePrizeTaken(game: LiveGame, byPlayer: Bool) {
        if byPlayer {
            game.playerPrizesRemaining = min(6, game.playerPrizesRemaining + 1)
        } else {
            game.opponentPrizesRemaining = min(6, game.opponentPrizesRemaining + 1)
        }
        save()
    }

    @discardableResult
    func endGame(game: LiveGame, result: MatchResult, notes: String) -> Match? {
        guard let deck = game.deck else { return nil }
        game.endedAt = .now
        if let active = game.turns.first(where: { $0.endedAt == nil }) {
            active.endedAt = game.endedAt
        }
        let match = MatchRepository(modelContext: context).logMatch(
            deck: deck,
            archetype: game.opponentArchetype,
            result: result,
            format: game.format,
            eventType: game.eventType,
            notes: notes,
            date: game.endedAt ?? .now
        )
        game.match = match
        match.liveGame = game
        save()
        return match
    }

    private func save() {
        try? context.save()
    }
}
