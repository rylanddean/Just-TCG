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

    // MARK: - comboOdds

    @Test func comboOddsSingleCardMatchesExactHypergeometric() {
        let odds = ConsistencyEngine.comboOdds(
            selectedCards: [ComboCardSelection(name: "Arven", copies: 4)],
            deckSize: 60
        )
        let exact = ConsistencyEngine.openingHandProbability(copies: 4, deckSize: 60)
        #expect(abs(odds.opening - exact) < 0.001)
    }

    @Test func comboOddsTwoCardLowerThanOneCard() {
        let single = ConsistencyEngine.comboOdds(
            selectedCards: [ComboCardSelection(name: "Arven", copies: 4)],
            deckSize: 60
        )
        let combo = ConsistencyEngine.comboOdds(
            selectedCards: [
                ComboCardSelection(name: "Arven", copies: 4),
                ComboCardSelection(name: "Boss's Orders", copies: 4),
            ],
            deckSize: 60
        )
        #expect(combo.opening < single.opening)
    }

    @Test func comboOddsEmptySelectionReturnsOne() {
        let odds = ConsistencyEngine.comboOdds(selectedCards: [], deckSize: 60)
        #expect(odds.opening   == 1.0)
        #expect(odds.byTurn2   == 1.0)
        #expect(odds.byTurn3   == 1.0)
        #expect(odds.byTurn4   == 1.0)
    }

    @Test func comboOddsMonotonicallyIncreasing() {
        let odds = ConsistencyEngine.comboOdds(
            selectedCards: [
                ComboCardSelection(name: "Arven", copies: 4),
                ComboCardSelection(name: "Ultra Ball", copies: 4),
            ],
            deckSize: 60
        )
        #expect(odds.byTurn2 >= odds.opening)
        #expect(odds.byTurn3 >= odds.byTurn2)
        #expect(odds.byTurn4 >= odds.byTurn3)
    }

    // MARK: - Group-based (AND + OR mixed)

    @Test func comboOddsGroupsSingleGroupMatchesOrExact() {
        // One group = OR: should match combined-pool hypergeometric exactly
        let group = ComboGroup(cards: [
            ComboCardSelection(name: "Arven", copies: 4),
            ComboCardSelection(name: "Ultra Ball", copies: 4),
        ])
        let odds = ConsistencyEngine.comboOdds(groups: [group], deckSize: 60)
        let exact = ConsistencyEngine.probabilityAtLeast(copies: 8, deckSize: 60, drawn: 7, desired: 1)
        #expect(abs(odds.opening - exact) < 0.001)
    }

    @Test func comboOddsGroupsAndIsLowerThanOr() {
        // Two single-card groups (AND) vs. one two-card group (OR) — AND must be lower
        let andGroups = [
            ComboGroup(cards: [ComboCardSelection(name: "Arven", copies: 4)]),
            ComboGroup(cards: [ComboCardSelection(name: "Boss's Orders", copies: 4)]),
        ]
        let orGroup = [ComboGroup(cards: [
            ComboCardSelection(name: "Arven", copies: 4),
            ComboCardSelection(name: "Boss's Orders", copies: 4),
        ])]
        let andOdds = ConsistencyEngine.comboOdds(groups: andGroups, deckSize: 60)
        let orOdds  = ConsistencyEngine.comboOdds(groups: orGroup,  deckSize: 60)
        #expect(andOdds.opening < orOdds.opening)
    }

    @Test func comboOddsGroupsMixedAndOrBetweenPureAnd() {
        // X AND (Y OR Z) should be between X-AND-Y and X-OR-Y-OR-Z
        let pureAnd = [
            ComboGroup(cards: [ComboCardSelection(name: "Arven", copies: 4)]),
            ComboGroup(cards: [ComboCardSelection(name: "Iono", copies: 4)]),
        ]
        let mixed = [
            ComboGroup(cards: [ComboCardSelection(name: "Arven", copies: 4)]),
            ComboGroup(cards: [
                ComboCardSelection(name: "Iono", copies: 4),
                ComboCardSelection(name: "Boss's Orders", copies: 4),
            ]),
        ]
        let pureOr = [ComboGroup(cards: [
            ComboCardSelection(name: "Arven", copies: 4),
            ComboCardSelection(name: "Iono", copies: 4),
            ComboCardSelection(name: "Boss's Orders", copies: 4),
        ])]
        let andOdds   = ConsistencyEngine.comboOdds(groups: pureAnd, deckSize: 60)
        let mixedOdds = ConsistencyEngine.comboOdds(groups: mixed,   deckSize: 60)
        let orOdds    = ConsistencyEngine.comboOdds(groups: pureOr,  deckSize: 60)
        // Ordering: pureAnd ≤ mixed ≤ pureOr (with some Monte Carlo tolerance)
        #expect(mixedOdds.opening >= andOdds.opening - 0.01)
        #expect(orOdds.opening    >= mixedOdds.opening - 0.01)
    }

    @Test func comboOddsGroupsEmptyReturnsOne() {
        let odds = ConsistencyEngine.comboOdds(groups: [], deckSize: 60)
        #expect(odds.opening == 1.0)
    }

    // MARK: - OR logic

    @Test func comboOddsOrSingleCardMatchesExact() {
        let exact = ConsistencyEngine.openingHandProbability(copies: 4, deckSize: 60)
        let odds = ConsistencyEngine.comboOdds(
            selectedCards: [ComboCardSelection(name: "Arven", copies: 4)],
            deckSize: 60,
            logic: .or
        )
        #expect(abs(odds.opening - exact) < 0.001)
    }

    @Test func comboOddsOrHigherThanAnd() {
        let cards = [
            ComboCardSelection(name: "Arven", copies: 4),
            ComboCardSelection(name: "Boss's Orders", copies: 4),
        ]
        let andOdds = ConsistencyEngine.comboOdds(selectedCards: cards, deckSize: 60, logic: .and)
        let orOdds  = ConsistencyEngine.comboOdds(selectedCards: cards, deckSize: 60, logic: .or)
        #expect(orOdds.opening > andOdds.opening)
    }

    @Test func comboOddsOrMatchesCombinedPool() {
        // OR over two 4-copy cards = hypergeometric with 8 copies in pool
        let exact = ConsistencyEngine.probabilityAtLeast(copies: 8, deckSize: 60, drawn: 7, desired: 1)
        let odds = ConsistencyEngine.comboOdds(
            selectedCards: [
                ComboCardSelection(name: "Arven", copies: 4),
                ComboCardSelection(name: "Ultra Ball", copies: 4),
            ],
            deckSize: 60,
            logic: .or
        )
        #expect(abs(odds.opening - exact) < 0.001)
    }

    @Test func comboOddsOrMonotonicallyIncreasing() {
        let odds = ConsistencyEngine.comboOdds(
            selectedCards: [
                ComboCardSelection(name: "Arven", copies: 4),
                ComboCardSelection(name: "Ultra Ball", copies: 4),
            ],
            deckSize: 60,
            logic: .or
        )
        #expect(odds.byTurn2 >= odds.opening)
        #expect(odds.byTurn3 >= odds.byTurn2)
        #expect(odds.byTurn4 >= odds.byTurn3)
    }
}
