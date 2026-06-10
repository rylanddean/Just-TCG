import Testing
import Foundation
import SwiftData
@testable import JustTCG

@Suite("DeckLegalityChecker")
struct DeckLegalityCheckerTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([CachedCard.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private func makeCard(
        setCode: String,
        number: String,
        name: String,
        supertype: String = "Pokémon",
        standard: Bool = true,
        regulationMark: String? = "H"
    ) -> CachedCard {
        CachedCard(
            id: "\(setCode)-\(number)",
            name: name,
            supertype: supertype,
            setCode: setCode,
            setName: setCode,
            number: number,
            isStandardLegal: standard,
            imageURL: "",
            regulationMark: regulationMark
        )
    }

    private func entry(_ setCode: String, _ number: String, _ name: String, _ qty: Int, supertype: String = "Pokémon") -> LimitlessDeckEntry {
        LimitlessDeckEntry(setCode: setCode, number: number, name: name, quantity: qty, supertype: supertype)
    }

    @Test func acceptsDeckOfHIJMarkedCardsAsLegal() throws {
        let context = try makeContext()
        context.insert(makeCard(setCode: "OBF", number: "125", name: "Charizard ex", regulationMark: "H"))
        context.insert(makeCard(setCode: "ASC", number: "204", name: "Team Rocket's Giovanni", supertype: "Trainer", regulationMark: "I"))
        context.insert(makeCard(setCode: "DRI", number: "170", name: "Team Rocket's Archer", supertype: "Trainer", regulationMark: "J"))

        let deck = LimitlessDeckList(listId: "x", entries: [
            entry("OBF", "125", "Charizard ex", 3),
            entry("ASC", "204", "Team Rocket's Giovanni", 4, supertype: "Trainer"),
            entry("DRI", "170", "Team Rocket's Archer", 4, supertype: "Trainer"),
        ])
        #expect(DeckLegalityChecker.check(deck, in: context) == .legal)
    }

    @Test func rejectsDeckContainingPreRotationCard() throws {
        let context = try makeContext()
        context.insert(makeCard(setCode: "OBF", number: "125", name: "Charizard ex", regulationMark: "H"))
        // Regulation G is no longer Standard (rotated).
        context.insert(makeCard(setCode: "OLD", number: "1", name: "Lost City", supertype: "Trainer", standard: false, regulationMark: "G"))

        let deck = LimitlessDeckList(listId: "x", entries: [
            entry("OBF", "125", "Charizard ex", 3),
            entry("OLD", "1", "Lost City", 2, supertype: "Trainer"),
        ])
        if case .rejected = DeckLegalityChecker.check(deck, in: context) {} else {
            Issue.record("expected rejected, got \(DeckLegalityChecker.check(deck, in: context))")
        }
    }

    @Test func returnsUncertainForUnknownCard() throws {
        // Local catalog can lag behind new set releases. We don't reject
        // outright but flag the deck as uncertain so the UI can warn the user.
        let context = try makeContext()
        context.insert(makeCard(setCode: "OBF", number: "125", name: "Charizard ex", regulationMark: "H"))
        let deck = LimitlessDeckList(listId: "x", entries: [
            entry("OBF", "125", "Charizard ex", 3),
            entry("XYZ", "999", "Unknown Card", 1, supertype: "Trainer"),
        ])
        #expect(DeckLegalityChecker.check(deck, in: context) == .uncertain(unknownCount: 1))
    }

    @Test func rejectionPayloadIncludesDiagnosticDetail() throws {
        let context = try makeContext()
        context.insert(makeCard(setCode: "OLD", number: "1", name: "Rotated Card", supertype: "Trainer", standard: false, regulationMark: "F"))
        let deck = LimitlessDeckList(listId: "x", entries: [
            entry("OLD", "1", "Rotated Card", 2, supertype: "Trainer"),
        ])
        let result = DeckLegalityChecker.check(deck, in: context)
        guard case .rejected(let setCode, _, let name, _) = result else {
            Issue.record("expected rejection, got \(result)"); return
        }
        #expect(setCode == "OLD")
        #expect(name == "Rotated Card")
    }

    @Test func ignoresBasicEnergyEntries() throws {
        let context = try makeContext()
        context.insert(makeCard(setCode: "OBF", number: "125", name: "Charizard ex", regulationMark: "H"))
        // Basic Energy is always Standard-legal — entry not in catalog must not produce uncertainty.
        let deck = LimitlessDeckList(listId: "x", entries: [
            entry("OBF", "125", "Charizard ex", 3),
            entry("SVE", "2", "Fire Energy", 8, supertype: "Energy"),
            entry("SVE", "10", "Basic Water Energy", 4, supertype: "Energy"),
        ])
        #expect(DeckLegalityChecker.check(deck, in: context) == .legal)
    }

    @Test func acceptsCardWithNilRegulationMarkButStandardLegalFlag() throws {
        // Some seeded cards have no regulation mark yet. As long as isStandardLegal is true, accept as .legal.
        let context = try makeContext()
        context.insert(makeCard(setCode: "OBF", number: "125", name: "Charizard ex", regulationMark: nil))
        let deck = LimitlessDeckList(listId: "x", entries: [
            entry("OBF", "125", "Charizard ex", 3),
        ])
        #expect(DeckLegalityChecker.check(deck, in: context) == .legal)
    }

    @Test func rejectsCardFlaggedNonStandardEvenIfMarkLooksRight() throws {
        // Belt-and-suspenders: if isStandardLegal is false, reject regardless of mark.
        let context = try makeContext()
        context.insert(makeCard(setCode: "OBF", number: "125", name: "Charizard ex", standard: false, regulationMark: "H"))
        let deck = LimitlessDeckList(listId: "x", entries: [
            entry("OBF", "125", "Charizard ex", 3),
        ])
        if case .rejected = DeckLegalityChecker.check(deck, in: context) {} else {
            Issue.record("expected rejected")
        }
    }
}
