import Testing
import Foundation
@testable import JustTCG

@Suite("CardIdentifierParser")
struct CardIdentifierParserTests {

    let parser = CardIdentifierParser()

    @Test func standardCard() {
        let lines = [
            "Charizard ex",
            "HP 330",
            "OBF 125/197",
            "G OBF"
        ]
        let result = parser.parse(lines: lines)
        #expect(result.cardName == "Charizard ex")
        #expect(result.cardNumber == "125")
        #expect(result.setCode == "OBF")
        #expect(result.confidence == .high)
    }

    @Test func basicEnergyCard() {
        let lines = [
            "Fire Energy",
            "SVE 004/008"
        ]
        let result = parser.parse(lines: lines)
        #expect(result.cardName == "Fire Energy")
        #expect(result.cardNumber == "004")
    }

    @Test func exCard() {
        let lines = [
            "Miraidon ex",
            "HP 220",
            "SVI 081/198"
        ]
        let result = parser.parse(lines: lines)
        #expect(result.cardName == "Miraidon ex")
        #expect(result.cardNumber == "081")
    }

    @Test func fullArtCard() {
        let lines = [
            "Professor's Research",
            "Supporter",
            "TEF 190/167"
        ]
        let result = parser.parse(lines: lines)
        #expect(result.cardNumber == "190")
        #expect(result.confidence != .low)
    }

    @Test func partialOCR() {
        let lines = ["Gardevoir", "HPl 160"]
        let result = parser.parse(lines: lines)
        #expect(result.cardName == "Gardevoir")
        #expect(result.cardNumber == nil)
        #expect(result.confidence == .medium || result.confidence == .low)
    }

    @Test func rawLinesPreserved() {
        let lines = ["Line A", "Line B"]
        let result = parser.parse(lines: lines)
        #expect(result.rawLines == lines)
    }
}
