import Testing
import Foundation
@testable import JustTCG

@Suite("LimitlessHTMLParser")
struct LimitlessHTMLParserTests {

    // Minimal <tr> that parsePlacements can extract
    private func placementRow(deck: String, rank: Int = 1) -> String {
        """
        <tr data-rank="\(rank)" data-name="Test Player" data-deck="\(deck)">
        <td><a href="/decks/list/999"></a></td>
        </tr>
        """
    }

    // MARK: - Named entity decoding

    @Test func enDashFromNamedEntity() {
        let html = placementRow(deck: "Gardevoir ex &ndash; Night Wanderer")
        let result = LimitlessHTMLParser.parsePlacements(from: html)
        #expect(result.first?.archetype == "Gardevoir ex – Night Wanderer")
    }

    @Test func emDashFromNamedEntity() {
        let html = placementRow(deck: "Control &mdash; No Prize")
        let result = LimitlessHTMLParser.parsePlacements(from: html)
        #expect(result.first?.archetype == "Control — No Prize")
    }

    @Test func accentedLetterFromNamedEntity() {
        let html = placementRow(deck: "Pok&eacute;mon Control")
        let result = LimitlessHTMLParser.parsePlacements(from: html)
        #expect(result.first?.archetype == "Pokémon Control")
    }

    // MARK: - Numeric entity decoding

    @Test func enDashFromDecimalEntity() {
        // U+2013 EN DASH = decimal 8211
        let html = placementRow(deck: "Gardevoir ex &#8211; Night Wanderer")
        let result = LimitlessHTMLParser.parsePlacements(from: html)
        #expect(result.first?.archetype == "Gardevoir ex – Night Wanderer")
    }

    @Test func enDashFromHexEntity() {
        let html = placementRow(deck: "Gardevoir ex &#x2013; Night Wanderer")
        let result = LimitlessHTMLParser.parsePlacements(from: html)
        #expect(result.first?.archetype == "Gardevoir ex – Night Wanderer")
    }

    @Test func hexEntityCaseInsensitive() {
        let html = placementRow(deck: "Gardevoir ex &#X2013; Night Wanderer")
        let result = LimitlessHTMLParser.parsePlacements(from: html)
        #expect(result.first?.archetype == "Gardevoir ex – Night Wanderer")
    }

    // MARK: - No regression on plain ASCII

    @Test func asciiNamesPassThrough() {
        let html = placementRow(deck: "Charizard ex")
        let result = LimitlessHTMLParser.parsePlacements(from: html)
        #expect(result.first?.archetype == "Charizard ex")
    }

    @Test func ampersandDecoded() {
        let html = placementRow(deck: "Pikachu &amp; Zekrom GX")
        let result = LimitlessHTMLParser.parsePlacements(from: html)
        #expect(result.first?.archetype == "Pikachu & Zekrom GX")
    }
}
