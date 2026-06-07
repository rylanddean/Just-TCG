import Testing
import Foundation
@testable import JustTCG

@Suite("MatchupStatsEngine")
struct MatchupStatsEngineTests {

    let engine = MatchupStatsEngine()

    // MARK: - Helpers

    private func match(
        archetype: String,
        result: MatchResult,
        daysAgo: Double = 0
    ) -> Match {
        Match(
            date: Date(timeIntervalSinceNow: -daysAgo * 86400),
            opponentArchetype: archetype,
            result: result
        )
    }

    // MARK: - compute(matches:)

    @Test func emptyInput() {
        let stats = engine.compute(matches: [])
        #expect(stats.isEmpty)
    }

    @Test func singleArchetype() {
        let matches = [
            match(archetype: "Charizard ex", result: .win),
            match(archetype: "Charizard ex", result: .win),
            match(archetype: "Charizard ex", result: .loss),
        ]
        let stats = engine.compute(matches: matches)
        #expect(stats.count == 1)
        let stat = stats[0]
        #expect(stat.archetype == "Charizard ex")
        #expect(stat.wins == 2)
        #expect(stat.losses == 1)
        #expect(stat.ties == 0)
        #expect(stat.sampleSize == 3)
        #expect(abs(stat.winRate - (2.0 / 3.0)) < 0.0001)
    }

    @Test func multipleArchetypes_sortedBySampleSizeDesc() {
        let matches = [
            match(archetype: "Lugia VSTAR", result: .win),
            match(archetype: "Dragapult ex", result: .win),
            match(archetype: "Dragapult ex", result: .loss),
            match(archetype: "Dragapult ex", result: .win),
        ]
        let stats = engine.compute(matches: matches)
        #expect(stats.count == 2)
        #expect(stats[0].archetype == "Dragapult ex")
        #expect(stats[0].sampleSize == 3)
        #expect(stats[1].archetype == "Lugia VSTAR")
        #expect(stats[1].sampleSize == 1)
    }

    @Test func tieOnlyMatchup() {
        let matches = [
            match(archetype: "Miraidon ex", result: .tie),
            match(archetype: "Miraidon ex", result: .tie),
        ]
        let stats = engine.compute(matches: matches)
        #expect(stats.count == 1)
        let stat = stats[0]
        #expect(stat.wins == 0)
        #expect(stat.losses == 0)
        #expect(stat.ties == 2)
        #expect(stat.sampleSize == 2)
        #expect(stat.winRate == 0.0)
    }

    // MARK: - compute(matches:since:)

    @Test func sinceFilter_excludesOldMatches() {
        let cutoff = Date(timeIntervalSinceNow: -7 * 86400)
        let matches = [
            match(archetype: "Gardevoir ex", result: .win, daysAgo: 3),
            match(archetype: "Gardevoir ex", result: .win, daysAgo: 10),
        ]
        let stats = engine.compute(matches: matches, since: cutoff)
        #expect(stats.count == 1)
        #expect(stats[0].sampleSize == 1)
    }

    @Test func sinceFilter_emptyWhenAllOld() {
        let cutoff = Date()
        let matches = [
            match(archetype: "Gardevoir ex", result: .win, daysAgo: 1),
        ]
        let stats = engine.compute(matches: matches, since: cutoff)
        #expect(stats.isEmpty)
    }

    // MARK: - overallRecord

    @Test func overallRecord_countsCorrectly() {
        let matches = [
            match(archetype: "A", result: .win),
            match(archetype: "B", result: .win),
            match(archetype: "A", result: .loss),
            match(archetype: "C", result: .tie),
        ]
        let record = engine.overallRecord(matches: matches)
        #expect(record.wins == 2)
        #expect(record.losses == 1)
        #expect(record.ties == 1)
    }

    @Test func overallRecord_empty() {
        let record = engine.overallRecord(matches: [])
        #expect(record.wins == 0)
        #expect(record.losses == 0)
        #expect(record.ties == 0)
    }

    // MARK: - Confidence & Tag

    @Test func confidence_sufficientAt5() {
        let matches = (0..<5).map { _ in match(archetype: "X", result: .win) }
        let stat = engine.compute(matches: matches)[0]
        #expect(stat.confidence == .sufficient)
        #expect(stat.tag == .favourable)
    }

    @Test func confidence_insufficientBelow5() {
        let matches = (0..<4).map { _ in match(archetype: "X", result: .win) }
        let stat = engine.compute(matches: matches)[0]
        #expect(stat.confidence == .insufficient)
        #expect(stat.tag == .insufficientData)
    }

    @Test func tag_unfavourableAt40PctOrBelow() {
        let matches = [
            match(archetype: "X", result: .win),
            match(archetype: "X", result: .win),
            match(archetype: "X", result: .loss),
            match(archetype: "X", result: .loss),
            match(archetype: "X", result: .loss),
        ]
        let stat = engine.compute(matches: matches)[0]
        #expect(stat.tag == .unfavourable)
    }

    @Test func tag_evenBetween40And60() {
        let matches = [
            match(archetype: "X", result: .win),
            match(archetype: "X", result: .win),
            match(archetype: "X", result: .win),
            match(archetype: "X", result: .loss),
            match(archetype: "X", result: .loss),
        ]
        let stat = engine.compute(matches: matches)[0]
        #expect(abs(stat.winRate - 0.6) < 0.0001)
        #expect(stat.tag == .favourable)
    }
}
