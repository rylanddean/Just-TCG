import Foundation
import SwiftData

enum MatchResult: String, Codable {
    case win, loss, tie
}

enum MatchFormat: String, Codable {
    case bo1, bo3
}

enum EventType: String, Codable {
    case casual
    case leagueChallenge
    case regionals
    case internationalChampionship
    case worldChampionship
}

@Model
final class Match {
    var id: UUID
    var date: Date
    var opponentArchetype: String
    var result: MatchResult
    var format: MatchFormat
    var eventType: EventType
    var notes: String
    var deck: Deck?
    var liveGame: LiveGame?

    init(
        date: Date = .now,
        opponentArchetype: String,
        result: MatchResult,
        format: MatchFormat = .bo3,
        eventType: EventType = .casual,
        notes: String = ""
    ) {
        self.id = UUID()
        self.date = date
        self.opponentArchetype = opponentArchetype
        self.result = result
        self.format = format
        self.eventType = eventType
        self.notes = notes
    }
}
