import Testing
import Foundation
@testable import JustTCG

@Suite("DeckSourceStrategy")
struct DeckSourceStrategyTests {

    // MARK: - Helpers

    private func makeCard(name: String, setCode: String, number: String, id: String? = nil) -> CachedCard {
        CachedCard(
            id: id ?? "\(setCode)-\(number)",
            name: name,
            supertype: "Pokémon",
            setCode: setCode,
            setName: setCode,
            number: number,
            isStandardLegal: true,
            imageURL: ""
        )
    }

    private func makePlacement(rank: Int = 1, deckListId: String?, archetype: String = "Charizard ex", tournamentName: String? = "Daytona Regional") -> LimitlessPlacement {
        LimitlessPlacement(
            rank: rank, playerName: "Alice", country: "US", archetype: archetype,
            wins: 7, losses: 1, ties: 0,
            deckListId: deckListId, playerId: nil,
            tournamentName: tournamentName
        )
    }

    private func makeDeck(listId: String, total: Int = 60) -> LimitlessDeckList {
        let entries: [LimitlessDeckEntry] = [
            LimitlessDeckEntry(setCode: "OBF", number: "125", name: "Charizard ex", quantity: 3, supertype: "Pokémon"),
            LimitlessDeckEntry(setCode: "OBF", number: "39", name: "Charmander", quantity: 4, supertype: "Pokémon"),
            LimitlessDeckEntry(setCode: "PAL", number: "185", name: "Iono", quantity: 4, supertype: "Trainer"),
            LimitlessDeckEntry(setCode: "SVE", number: "2", name: "Fire Energy", quantity: total - 11, supertype: "Energy"),
        ]
        return LimitlessDeckList(listId: listId, entries: entries)
    }

    // MARK: - Tests

    @Test func emptyCandidatesReturnsNil() async {
        let strategy = DeckSourceStrategy(
            fetchDecklists: { _, _ in Issue.record("should not fetch"); return [] },
            fetchDeck:      { _ in Issue.record("should not fetch"); return LimitlessDeckList(listId: "x", entries: []) }
        )
        let result = await strategy.lookup(candidates: [])
        #expect(result == nil)
    }

    @Test func hitsFirstCandidateAndReturnsFormattedDeck() async {
        let card = makeCard(name: "Charizard ex", setCode: "OBF", number: "125")
        let strategy = DeckSourceStrategy(
            fetchDecklists: { setCode, number in
                #expect(setCode == "OBF")
                #expect(number == "125")
                return [self.makePlacement(deckListId: "12345")]
            },
            fetchDeck: { listId in
                #expect(listId == "12345")
                return self.makeDeck(listId: listId)
            }
        )
        let result = await strategy.lookup(candidates: [card])
        #expect(result?.label.contains("Charizard ex") == true)
        #expect(result?.label.contains("Alice") == true)
        #expect(result?.label.contains("Daytona Regional") == true)
        #expect(result?.deckList.contains("Total Cards: 60") == true)
        #expect(result?.sourceCardId == card.id)
    }

    @Test func skipsPlacementsWithoutDeckListId() async {
        let card = makeCard(name: "Charizard ex", setCode: "OBF", number: "125")
        let strategy = DeckSourceStrategy(
            fetchDecklists: { _, _ in [self.makePlacement(deckListId: nil)] },
            fetchDeck:      { _ in Issue.record("should not fetch deck when no listId"); return LimitlessDeckList(listId: "x", entries: []) }
        )
        let result = await strategy.lookup(candidates: [card])
        #expect(result == nil)
    }

    @Test func fallsThroughToNextCandidateOnFetchError() async {
        let first = makeCard(name: "Charizard VMAX", setCode: "DAA", number: "20", id: "first")
        let second = makeCard(name: "Charizard ex", setCode: "OBF", number: "125", id: "second")
        let strategy = DeckSourceStrategy(
            fetchDecklists: { setCode, _ in
                if setCode == "DAA" { throw LimitlessClientError.invalidResponse(500) }
                return [self.makePlacement(deckListId: "ok")]
            },
            fetchDeck: { listId in self.makeDeck(listId: listId) }
        )
        let result = await strategy.lookup(candidates: [first, second])
        #expect(result?.sourceCardId == "second")
    }

    @Test func rejectsDecksOutsideTotalCardRange() async {
        let card = makeCard(name: "Charizard ex", setCode: "OBF", number: "125")
        let strategy = DeckSourceStrategy(
            fetchDecklists: { _, _ in [self.makePlacement(deckListId: "tiny")] },
            fetchDeck:      { _ in self.makeDeck(listId: "tiny", total: 30) }
        )
        let result = await strategy.lookup(candidates: [card])
        #expect(result == nil)
    }

    @Test func skipsRejectedDecksUntilLegalOneFound() async {
        let card = makeCard(name: "Charizard ex", setCode: "OBF", number: "125")
        let strategy = DeckSourceStrategy(
            fetchDecklists: { _, _ in [
                self.makePlacement(rank: 1, deckListId: "old"),
                self.makePlacement(rank: 2, deckListId: "old2"),
                self.makePlacement(rank: 3, deckListId: "new"),
            ] },
            fetchDeck: { listId in self.makeDeck(listId: listId) }
        )
        // Reject anything whose listId starts with "old"; accept others as legal.
        let result = await strategy.lookup(candidates: [card]) { deck in
            deck.listId.hasPrefix("old")
                ? .rejected(setCode: "X", number: "1", name: "rotated", reason: "test")
                : .legal
        }
        #expect(result?.deckList.contains("Total Cards: 60") == true)
        #expect(result?.label.contains("Charizard ex") == true)
        #expect(result?.hasUnknownCards == false)
    }

    @Test func returnsNilWhenAllPlacementsRejected() async {
        let card = makeCard(name: "Charizard ex", setCode: "OBF", number: "125")
        let strategy = DeckSourceStrategy(
            fetchDecklists: { _, _ in [
                self.makePlacement(rank: 1, deckListId: "a"),
                self.makePlacement(rank: 2, deckListId: "b"),
            ] },
            fetchDeck: { listId in self.makeDeck(listId: listId) }
        )
        let result = await strategy.lookup(candidates: [card]) { _ in
            .rejected(setCode: "X", number: "1", name: "rotated", reason: "test")
        }
        #expect(result == nil)
    }

    @Test func prefersLegalOverUncertainWithinSameCandidate() async {
        let card = makeCard(name: "Charizard ex", setCode: "OBF", number: "125")
        let strategy = DeckSourceStrategy(
            fetchDecklists: { _, _ in [
                self.makePlacement(rank: 1, deckListId: "uncertain"),
                self.makePlacement(rank: 2, deckListId: "legal"),
            ] },
            fetchDeck: { listId in self.makeDeck(listId: listId) }
        )
        let result = await strategy.lookup(candidates: [card]) { deck in
            deck.listId == "legal" ? .legal : .uncertain(unknownCount: 3)
        }
        #expect(result?.hasUnknownCards == false)
    }

    @Test func returnsUncertainWhenNoLegalFound() async {
        let card = makeCard(name: "Charizard ex", setCode: "OBF", number: "125")
        let strategy = DeckSourceStrategy(
            fetchDecklists: { _, _ in [
                self.makePlacement(rank: 1, deckListId: "uncertain1"),
                self.makePlacement(rank: 2, deckListId: "uncertain2"),
            ] },
            fetchDeck: { listId in self.makeDeck(listId: listId) }
        )
        let result = await strategy.lookup(candidates: [card]) { _ in .uncertain(unknownCount: 5) }
        #expect(result?.hasUnknownCards == true)
        #expect(result?.deckList.contains("Total Cards: 60") == true)
    }

    @Test func returnsNilWhenAllCandidatesFail() async {
        let card = makeCard(name: "Charizard ex", setCode: "OBF", number: "125")
        let strategy = DeckSourceStrategy(
            fetchDecklists: { _, _ in throw LimitlessClientError.offline },
            fetchDeck:      { _ in Issue.record("unreachable"); return LimitlessDeckList(listId: "x", entries: []) }
        )
        let result = await strategy.lookup(candidates: [card])
        #expect(result == nil)
    }
}
