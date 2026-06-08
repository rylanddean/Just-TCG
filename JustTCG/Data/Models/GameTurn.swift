import Foundation
import SwiftData

@Model
final class GameTurn {
    var id: UUID
    var turnNumber: Int
    var isPlayerTurn: Bool
    var startedAt: Date
    var endedAt: Date?
    var playerPrizesAtStart: Int
    var opponentPrizesAtStart: Int
    var prizesTaken: Int
    var game: LiveGame?

    var duration: TimeInterval? {
        guard let end = endedAt else { return nil }
        return end.timeIntervalSince(startedAt)
    }

    init(
        turnNumber: Int,
        isPlayerTurn: Bool,
        playerPrizesAtStart: Int,
        opponentPrizesAtStart: Int,
        prizesTaken: Int = 0
    ) {
        self.id = UUID()
        self.turnNumber = turnNumber
        self.isPlayerTurn = isPlayerTurn
        self.startedAt = .now
        self.playerPrizesAtStart = playerPrizesAtStart
        self.opponentPrizesAtStart = opponentPrizesAtStart
        self.prizesTaken = prizesTaken
    }
}
