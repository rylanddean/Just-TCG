import Testing
import Foundation
import SwiftData
@testable import JustTCG

@Suite("DeckImportLookup")
@MainActor
struct DeckImportLookupTests {

    // MARK: - Helpers

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: CachedCard.self, configurations: config)
        return ModelContext(container)
    }

    @discardableResult
    private func seedCard(in context: ModelContext, setCode: String, number: String, id: String? = nil) -> CachedCard {
        let card = CachedCard(
            id: id ?? "\(setCode.lowercased())-\(number)",
            name: "Test Card",
            setCode: setCode,
            setName: "Test Set",
            number: number,
            imageURL: "https://example.com/img.png"
        )
        context.insert(card)
        return card
    }

    private func entry(setCode: String, number: String, qty: Int = 1) -> DeckImportEntry {
        DeckImportEntry(quantity: qty, name: "Test", setCode: setCode, number: number)
    }

    // MARK: - Tests

    @Test func matchedEntryReturnsCardId() throws {
        let context = try makeContext()
        let card = seedCard(in: context, setCode: "OBF", number: "164")
        let results = DeckImportLookup().resolve([entry(setCode: "OBF", number: "164")], in: context)
        #expect(results.count == 1)
        #expect(results[0].cardId == card.id)
        #expect(results[0].isMatched)
    }

    @Test func unknownSetCodeReturnsNil() throws {
        let context = try makeContext()
        let results = DeckImportLookup().resolve([entry(setCode: "XYZ", number: "1")], in: context)
        #expect(results.count == 1)
        #expect(results[0].cardId == nil)
        #expect(!results[0].isMatched)
    }

    @Test func knownSetWrongNumberReturnsNil() throws {
        let context = try makeContext()
        seedCard(in: context, setCode: "OBF", number: "164")
        let results = DeckImportLookup().resolve([entry(setCode: "OBF", number: "999")], in: context)
        #expect(results[0].cardId == nil)
    }

    @Test func inputOrderPreserved() throws {
        let context = try makeContext()
        let card1 = seedCard(in: context, setCode: "OBF", number: "164")
        let card2 = seedCard(in: context, setCode: "MEW", number: "73")
        let entries = [
            entry(setCode: "OBF", number: "164"),
            entry(setCode: "XYZ", number: "0"),
            entry(setCode: "MEW", number: "73"),
        ]
        let results = DeckImportLookup().resolve(entries, in: context)
        #expect(results.count == 3)
        #expect(results[0].cardId == card1.id)
        #expect(results[1].cardId == nil)
        #expect(results[2].cardId == card2.id)
    }
}
