import Testing
import Foundation
@testable import JustTCG

@Suite("ConsistencyEngine")
struct ConsistencyEngineTests {

    let engine = ConsistencyEngine()

    // MARK: - openingHandProbability

    @Test func openingHand4Copies() {
        let p = ConsistencyEngine.openingHandProbability(copies: 4, deckSize: 60)
        #expect(abs(p - 0.398) < 0.002)
    }

    @Test func openingHand1Copy() {
        let p = ConsistencyEngine.openingHandProbability(copies: 1, deckSize: 60)
        #expect(abs(p - 0.117) < 0.002)
    }

    @Test func openingHandZeroCopies() {
        let p = ConsistencyEngine.openingHandProbability(copies: 0, deckSize: 60)
        #expect(p == 0.0)
    }

    // MARK: - probabilityByTurn

    @Test func byTurn2SecondGreaterThanFirst() {
        let result = ConsistencyEngine.probabilityByTurn(copies: 4, deckSize: 60, turn: 2)
        #expect(result.second > result.first)
    }

    @Test func byTurn1BothAtLeastOpeningHand() {
        let t1 = ConsistencyEngine.probabilityByTurn(copies: 4, deckSize: 60, turn: 1)
        let opening = ConsistencyEngine.openingHandProbability(copies: 4, deckSize: 60)
        // going-second draws an extra card on turn 1
        #expect(t1.first == opening)
        #expect(t1.second > opening)
    }

    // MARK: - consistencyScore monotonicity

    @Test func scoreMonotonicallyIncreasesWithDrawSearch() {
        let noSupport   = [DeckCardEntry(name: "Pikachu", copies: 4)]
        let withDraw    = noSupport + [DeckCardEntry(name: "Bibarel", copies: 4)]
        let withBoth    = withDraw  + [DeckCardEntry(name: "Ultra Ball", copies: 4)]

        let noDraw   = { (_: String) -> [String] in [] }
        let drawOnly = { (n: String) -> [String] in n == "Bibarel"   ? ["Draw"]   : [] }
        let both     = { (n: String) -> [String] in n == "Bibarel"   ? ["Draw"]   :
                                                    n == "Ultra Ball" ? ["Search"] : [] }

        let s0 = engine.consistencyScore(cards: noSupport, roleTags: noDraw)
        let s1 = engine.consistencyScore(cards: withDraw,  roleTags: drawOnly)
        let s2 = engine.consistencyScore(cards: withBoth,  roleTags: both)

        #expect(s0 < s1)
        #expect(s1 < s2)
    }

    // MARK: - breakdown

    @Test func breakdownSortedByCountThenName() {
        let entries = [
            DeckCardEntry(name: "Arcanine", copies: 2),
            DeckCardEntry(name: "Bibarel",  copies: 4),
            DeckCardEntry(name: "Zoroark",  copies: 2),
        ]
        let bd = engine.breakdown(entries: entries, deckSize: 60) { _ in [] }
        #expect(bd.keyCards[0].name == "Bibarel")
        #expect(bd.keyCards[1].name == "Arcanine")
        #expect(bd.keyCards[2].name == "Zoroark")
    }

    @Test func breakdownCountsDrawAndSearch() {
        let entries = [
            DeckCardEntry(name: "Bibarel",   copies: 4),
            DeckCardEntry(name: "Ultra Ball", copies: 4),
        ]
        let roleTags = { (n: String) -> [String] in
            n == "Bibarel"    ? ["Draw"]   :
            n == "Ultra Ball" ? ["Search"] : []
        }
        let bd = engine.breakdown(entries: entries, deckSize: 60, roleTags: roleTags)
        #expect(bd.drawCount   == 4)
        #expect(bd.searchCount == 4)
        #expect(bd.consistencyScore == min(100, (4 + 4) * 5))
    }
}
