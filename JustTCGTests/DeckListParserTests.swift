import Testing
import Foundation
@testable import JustTCG

@Suite("DeckListParser")
struct DeckListParserTests {

    // MARK: - Edge cases

    @Test func emptyInputReturnsEmpty() {
        #expect(DeckListParser.parse("").isEmpty)
    }

    @Test func blankLinesSkipped() {
        let text = "\n\n4 Pikachu EVO 26\n\n"
        let result = DeckListParser.parse(text)
        #expect(result.count == 1)
    }

    @Test func lineTooShortSkipped() {
        // qty + name + setCode only — no number token
        #expect(DeckListParser.parse("2 Pikachu EVO").isEmpty)
    }

    @Test func invalidQuantitySkipped() {
        #expect(DeckListParser.parse("abc Pikachu EVO 26").isEmpty)
    }

    @Test func zeroQuantitySkipped() {
        #expect(DeckListParser.parse("0 Pikachu EVO 26").isEmpty)
    }

    // MARK: - Section headers produce no entries

    @Test func sectionHeadersSkipped() {
        let text = """
        Pokémon: 4
        Pokemon: 4
        Trainer: 10
        Energy: 2
        """
        #expect(DeckListParser.parse(text).isEmpty)
    }

    @Test func totalCardsLineSkipped() {
        #expect(DeckListParser.parse("Total Cards: 60").isEmpty)
    }

    // MARK: - Card line parsing

    @Test func singleWordName() {
        let entries = DeckListParser.parse("3 Pikachu EVO 26")
        #expect(entries.count == 1)
        let e = entries[0]
        #expect(e.quantity == 3)
        #expect(e.name == "Pikachu")
        #expect(e.setCode == "EVO")
        #expect(e.number == "26")
    }

    @Test func multiWordName() {
        let entries = DeckListParser.parse("4 Buddy-Buddy Poffin TWM 144")
        #expect(entries.count == 1)
        let e = entries[0]
        #expect(e.quantity == 4)
        #expect(e.name == "Buddy-Buddy Poffin")
        #expect(e.setCode == "TWM")
        #expect(e.number == "144")
    }

    @Test func energyLineWithBraces() {
        let entries = DeckListParser.parse("4 Basic {D} Energy SVE 8")
        #expect(entries.count == 1)
        let e = entries[0]
        #expect(e.name == "Basic {D} Energy")
        #expect(e.setCode == "SVE")
        #expect(e.number == "8")
    }

    @Test func specialCharactersPreserved() {
        // é and ' are preserved verbatim
        let entries = DeckListParser.parse("2 Gardevoir ex SVI 86")
        #expect(entries[0].name == "Gardevoir ex")
    }

    // MARK: - Full deck list

    @Test func fullDeckList() {
        let text = """
        Pokémon: 4
        4 Pidgeot ex OBF 164
        3 Pidgey MEW 73
        Trainer: 3
        4 Buddy-Buddy Poffin TWM 144
        Energy: 2
        4 Basic {D} Energy SVE 8
        1 Basic {G} Energy SVE 1
        Total Cards: 60
        """
        let entries = DeckListParser.parse(text)
        #expect(entries.count == 5)

        #expect(entries[0].quantity == 4)
        #expect(entries[0].name == "Pidgeot ex")
        #expect(entries[0].setCode == "OBF")
        #expect(entries[0].number == "164")

        #expect(entries[1].quantity == 3)
        #expect(entries[1].name == "Pidgey")
        #expect(entries[1].setCode == "MEW")
        #expect(entries[1].number == "73")

        #expect(entries[2].name == "Buddy-Buddy Poffin")

        #expect(entries[3].name == "Basic {D} Energy")
        #expect(entries[4].name == "Basic {G} Energy")
    }
}
