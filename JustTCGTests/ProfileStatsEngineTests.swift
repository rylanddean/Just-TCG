import Testing
import Foundation
@testable import JustTCG

@Suite("ProfileStatsEngine")
struct ProfileStatsEngineTests {

    let engine = ProfileStatsEngine()

    private func match(_ result: MatchResult, daysAgo: Double = 0) -> Match {
        Match(date: Date(timeIntervalSinceNow: -daysAgo * 86400),
              opponentArchetype: "Test", result: result)
    }

    @Test func emptyInput() {
        let stats = engine.compute(matches: [], decks: [])
        #expect(stats.totalGames == 0)
        #expect(stats.winRate == nil)
        #expect(stats.currentStreak == 0)
        #expect(stats.longestWinStreak == 0)
    }

    @Test func allWins() {
        let matches = [match(.win, daysAgo: 2), match(.win, daysAgo: 1), match(.win)]
        let stats = engine.compute(matches: matches, decks: [])
        #expect(stats.wins == 3)
        #expect(stats.totalGames == 3)
        #expect(abs((stats.winRate ?? 0) - 1.0) < 0.001)
        #expect(stats.currentStreak == 3)
        #expect(stats.longestWinStreak == 3)
    }

    @Test func allLosses() {
        let matches = [match(.loss, daysAgo: 2), match(.loss, daysAgo: 1), match(.loss)]
        let stats = engine.compute(matches: matches, decks: [])
        #expect(stats.losses == 3)
        #expect(stats.currentStreak == -3)
        #expect(stats.longestWinStreak == 0)
    }

    @Test func mixedRecord() {
        let matches = [
            match(.win,  daysAgo: 4),
            match(.loss, daysAgo: 3),
            match(.win,  daysAgo: 2),
            match(.win,  daysAgo: 1),
            match(.win)
        ]
        let stats = engine.compute(matches: matches, decks: [])
        #expect(stats.wins == 4)
        #expect(stats.losses == 1)
        #expect(stats.currentStreak == 3)
        #expect(stats.longestWinStreak == 3)
    }

    @Test func tieBreaksStreak() {
        let matches = [
            match(.win,  daysAgo: 2),
            match(.win,  daysAgo: 1),
            match(.tie)
        ]
        let stats = engine.compute(matches: matches, decks: [])
        #expect(stats.currentStreak == 0)
    }

    @Test func bestWorstMatchupRequiresFiveGames() {
        let matches = (0..<4).map { _ in match(.win) }
        let stats = engine.compute(matches: matches, decks: [])
        #expect(stats.bestMatchup == nil)
        #expect(stats.worstMatchup == nil)
    }
}
