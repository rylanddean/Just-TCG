import Foundation
import SwiftData
import Observation
import UIKit

@Observable
final class LiveGameHUDViewModel {
    let game: LiveGame
    private let repo: LiveGameRepository

    // End-game sheet state
    var showEndGame = false
    var endGameResult: MatchResult? = nil
    var endGameNotes = ""

    // Long-press reverse confirmation
    var reverseAlertForPlayer: Bool? = nil  // nil = not showing; true/false = which side

    var activeTurn: GameTurn? {
        game.turns.max(by: { $0.turnNumber < $1.turnNumber })
    }

    var isPlayerTurn: Bool {
        activeTurn?.isPlayerTurn ?? game.isPlayerGoingFirst
    }

    var needsCoinFlip: Bool { game.turns.isEmpty }

    var isGameOver: Bool {
        game.playerPrizesRemaining == 0 || game.opponentPrizesRemaining == 0
    }

    private var reminderTimer: Timer?

    init(game: LiveGame, modelContext: ModelContext) {
        self.game = game
        self.repo = LiveGameRepository(modelContext: modelContext)
    }

    // MARK: - Turn reminder timer

    func startTurnReminderTimer() {
        stopTurnReminderTimer()
        reminderTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self,
                  self.activeTurn != nil,
                  !self.isGameOver,
                  !self.needsCoinFlip else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }

    func stopTurnReminderTimer() {
        reminderTimer?.invalidate()
        reminderTimer = nil
    }

    func confirmGoingFirst(isPlayerFirst: Bool) {
        repo.startTurn(game: game, isPlayerTurn: isPlayerFirst)
        startTurnReminderTimer()
    }

    func endTurn() {
        repo.startTurn(game: game, isPlayerTurn: !isPlayerTurn)
        startTurnReminderTimer()
    }

    func takePrize(byPlayer: Bool) {
        repo.recordPrizeTaken(game: game, byPlayer: byPlayer)
        stopTurnReminderTimer()
    }

    func reversePrize(byPlayer: Bool) {
        repo.reversePrizeTaken(game: game, byPlayer: byPlayer)
    }

    @discardableResult
    func endGame() -> Match? {
        guard let result = endGameResult else { return nil }
        stopTurnReminderTimer()
        return repo.endGame(game: game, result: result, notes: endGameNotes)
    }
}
