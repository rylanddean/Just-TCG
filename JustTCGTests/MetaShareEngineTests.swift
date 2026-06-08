import Testing
import Foundation
@testable import JustTCG

@Suite("MetaShareEngine")
struct MetaShareEngineTests {

    let engine = MetaShareEngine()

    // MARK: - Helpers

    private func detail(id: String, archetypes: [String]) -> LimitlessTournamentDetail {
        let placements = archetypes.enumerated().map { i, arch in
            LimitlessPlacement(
                rank: i + 1,
                playerName: "Player \(i)",
                country: "US",
                archetype: arch,
                wins: 0, losses: 0, ties: 0,
                deckListId: nil,
                playerId: nil
            )
        }
        return LimitlessTournamentDetail(id: id, placements: placements)
    }

    // MARK: - compute

    @Test func emptyInput() {
        let result = engine.compute(tournaments: [])
        #expect(result.isEmpty)
    }

    @Test func singleTournament_correctShares() {
        let t = detail(id: "1", archetypes: ["Charizard ex", "Charizard ex", "Dragapult ex"])
        let result = engine.compute(tournaments: [t])
        #expect(result.count == 2)
        #expect(result[0].archetype == "Charizard ex")
        #expect(abs(result[0].sharePercent - 66.666) < 0.1)
        #expect(result[1].archetype == "Dragapult ex")
        #expect(abs(result[1].sharePercent - 33.333) < 0.1)
    }

    @Test func multipleTournaments_aggregatesAcrossEvents() {
        let t1 = detail(id: "1", archetypes: ["Charizard ex", "Dragapult ex"])
        let t2 = detail(id: "2", archetypes: ["Charizard ex", "Lugia VSTAR"])
        let result = engine.compute(tournaments: [t1, t2])
        // Total 4 players: Charizard ex 2, Dragapult ex 1, Lugia VSTAR 1
        let charizard = result.first { $0.archetype == "Charizard ex" }
        #expect(charizard != nil)
        #expect(abs(charizard!.sharePercent - 50.0) < 0.01)
        #expect(charizard!.tournaments == 2)
    }

    @Test func archetypeNormalisation_mergesDifferentCapitalisation() {
        let t = detail(id: "1", archetypes: ["charizard ex", "Charizard ex", "CHARIZARD EX"])
        let result = engine.compute(tournaments: [t])
        #expect(result.count == 1)
        #expect(abs(result[0].sharePercent - 100.0) < 0.01)
    }

    @Test func archetypeNormalisation_trimsWhitespace() {
        let t = detail(id: "1", archetypes: ["Dragapult ex", " Dragapult ex ", "Dragapult ex"])
        let result = engine.compute(tournaments: [t])
        #expect(result.count == 1)
    }

    @Test func sortedByShareDesc() {
        let t = detail(id: "1", archetypes: ["A", "B", "B", "B", "C", "C"])
        let result = engine.compute(tournaments: [t])
        let shares = result.map(\.sharePercent)
        #expect(shares == shares.sorted(by: >))
    }

    // MARK: - topArchetypes

    @Test func topArchetypes_limitsResults() {
        let t = detail(id: "1", archetypes: ["A", "B", "C", "D", "E"])
        let result = engine.topArchetypes(limit: 3, tournaments: [t])
        #expect(result.count == 3)
    }

    @Test func topArchetypes_emptyInput() {
        let result = engine.topArchetypes(limit: 5, tournaments: [])
        #expect(result.isEmpty)
    }

    @Test func tournaments_countPerArchetype() {
        let t1 = detail(id: "1", archetypes: ["Charizard ex"])
        let t2 = detail(id: "2", archetypes: ["Charizard ex"])
        let t3 = detail(id: "3", archetypes: ["Dragapult ex"])
        let result = engine.compute(tournaments: [t1, t2, t3])
        let charizard = result.first { $0.archetype == "Charizard ex" }
        let dragapult = result.first { $0.archetype == "Dragapult ex" }
        #expect(charizard?.tournaments == 2)
        #expect(dragapult?.tournaments == 1)
    }
}
