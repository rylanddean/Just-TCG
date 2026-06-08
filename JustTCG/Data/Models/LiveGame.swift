import Foundation
import SwiftData

@Model
final class LiveGame {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var opponentArchetype: String
    var eventType: EventType
    var format: MatchFormat
    var isPlayerGoingFirst: Bool
    var playerPrizesRemaining: Int
    var opponentPrizesRemaining: Int
    var deck: Deck?
    var match: Match?
    @Relationship(deleteRule: .cascade) var turns: [GameTurn] = []

    init(
        opponentArchetype: String,
        eventType: EventType,
        format: MatchFormat,
        isPlayerGoingFirst: Bool
    ) {
        self.id = UUID()
        self.startedAt = .now
        self.opponentArchetype = opponentArchetype
        self.eventType = eventType
        self.format = format
        self.isPlayerGoingFirst = isPlayerGoingFirst
        self.playerPrizesRemaining = 6
        self.opponentPrizesRemaining = 6
    }
}
