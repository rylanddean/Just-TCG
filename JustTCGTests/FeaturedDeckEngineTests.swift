import Testing
import Foundation
@testable import JustTCG

@Suite("FeaturedDeckEngine")
struct FeaturedDeckEngineTests {

    private func makeTournament(id: String = "t1") -> LimitlessTournament {
        LimitlessTournament(id: id, name: "Regional \(id)", date: Date(), country: "US", format: "Standard", playerCount: 128)
    }

    private func makeCandidate(rank: Int, archetype: String = "Charizard ex", deckListId: String? = "dl1", tournamentId: String = "t1") -> FeaturedDeckCandidate {
        let placement = LimitlessPlacement(
            rank: rank, playerName: "Player \(rank)", country: "US",
            archetype: archetype, wins: 5, losses: 2, ties: 0,
            deckListId: deckListId, playerId: nil
        )
        return FeaturedDeckCandidate(tournament: makeTournament(id: tournamentId), placement: placement)
    }

    @Test func emptyPoolReturnsNil() {
        #expect(FeaturedDeckEngine.pick(from: []) == nil)
    }

    @Test func allRanksAbove8ReturnsNil() {
        let candidates = [makeCandidate(rank: 9), makeCandidate(rank: 16)]
        #expect(FeaturedDeckEngine.pick(from: candidates) == nil)
    }

    @Test func sameDateProducesSamePick() {
        let candidates = (1...8).map { makeCandidate(rank: $0, tournamentId: "t\($0)") }
        let date = Date()
        let r1 = FeaturedDeckEngine.pick(from: candidates, date: date)
        let r2 = FeaturedDeckEngine.pick(from: candidates, date: date)
        #expect(r1?.playerName == r2?.playerName)
    }

    @Test func differentCalendarDaysProduceDifferentIndices() {
        let today = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let candidates = (1...8).map { makeCandidate(rank: $0, archetype: "Archetype \($0)", tournamentId: "t\($0)") }
        let ordToday = Calendar.current.ordinality(of: .day, in: .era, for: today) ?? 0
        let ordTomorrow = Calendar.current.ordinality(of: .day, in: .era, for: tomorrow) ?? 0
        #expect(ordToday % candidates.count != ordTomorrow % candidates.count)
    }

    @Test func threePartArchetypeParsed() {
        let candidate = makeCandidate(rank: 1, archetype: "Dragapult ex / Pidgeot ex / Duskull")
        let result = FeaturedDeckEngine.pick(from: [candidate])
        #expect(result?.primaryCardNames == ["Dragapult ex", "Pidgeot ex", "Duskull"])
    }

    @Test func moreThanThreeSegmentsCapped() {
        let candidate = makeCandidate(rank: 1, archetype: "A / B / C / D")
        let result = FeaturedDeckEngine.pick(from: [candidate])
        #expect(result?.primaryCardNames.count == 3)
        #expect(result?.primaryCardNames == ["A", "B", "C"])
    }

    @Test func singleNameArchetype() {
        let candidate = makeCandidate(rank: 1, archetype: "Charizard ex")
        let result = FeaturedDeckEngine.pick(from: [candidate])
        #expect(result?.primaryCardNames == ["Charizard ex"])
    }

    @Test func fetchedAtEqualsDateArgument() {
        let date = Date(timeIntervalSince1970: 1_000_000)
        let result = FeaturedDeckEngine.pick(from: [makeCandidate(rank: 1)], date: date)
        #expect(result?.fetchedAt == date)
    }

    @Test func rank8IsIncluded() {
        let candidate = makeCandidate(rank: 8)
        #expect(FeaturedDeckEngine.pick(from: [candidate]) != nil)
    }

    @Test func rank9IsExcluded() {
        let rank8 = makeCandidate(rank: 8, archetype: "Dragapult ex")
        let rank9 = makeCandidate(rank: 9, archetype: "Charizard ex")
        let candidates = [rank9, rank8]
        let result = FeaturedDeckEngine.pick(from: candidates)
        #expect(result?.archetype == "Dragapult ex")
    }
}
