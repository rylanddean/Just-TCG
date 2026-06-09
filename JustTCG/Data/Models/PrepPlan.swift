import Foundation
import SwiftData

@Model
final class PrepPlan {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String
    var tournamentDate: Date
    var deckID: UUID?
    var createdAt: Date = Date.now
    @Relationship(deleteRule: .cascade) var matchupGoals: [MatchupGoal] = []

    init(name: String, tournamentDate: Date, deckID: UUID? = nil) {
        self.name = name
        self.tournamentDate = tournamentDate
        self.deckID = deckID
    }

    var overallProgress: Double {
        guard !matchupGoals.isEmpty else { return 0 }
        let target = matchupGoals.reduce(0) { $0 + $1.targetSessionCount }
        guard target > 0 else { return 0 }
        let done = matchupGoals.reduce(0) { $0 + min($1.completedCount, $1.targetSessionCount) }
        return Double(done) / Double(target)
    }

    var daysUntilTournament: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date.now)
        let target = cal.startOfDay(for: tournamentDate)
        return cal.dateComponents([.day], from: today, to: target).day ?? 0
    }
}

@Model
final class MatchupGoal {
    @Attribute(.unique) var id: UUID = UUID()
    var archetypeName: String
    var targetSessionCount: Int
    var plan: PrepPlan?
    @Relationship(deleteRule: .cascade) var sessions: [PrepSession] = []

    init(archetypeName: String, targetSessionCount: Int) {
        self.archetypeName = archetypeName
        self.targetSessionCount = targetSessionCount
    }

    var completedCount: Int { sessions.count }

    var winRate: Double? {
        guard !sessions.isEmpty else { return nil }
        let wins = sessions.filter { $0.result == .win }.count
        return Double(wins) / Double(sessions.count)
    }

    var isComplete: Bool { completedCount >= targetSessionCount }
}

@Model
final class PrepSession {
    @Attribute(.unique) var id: UUID = UUID()
    var playedAt: Date = Date.now
    var result: MatchResult
    var notes: String = ""
    var goal: MatchupGoal?

    init(result: MatchResult, notes: String = "") {
        self.result = result
        self.notes = notes
    }
}
