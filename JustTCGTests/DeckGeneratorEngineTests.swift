import Testing
import Foundation
import SwiftData
@testable import JustTCG

@Suite("DeckGeneratorCatalog")
struct DeckGeneratorCatalogTests {

    // MARK: - Keyword extraction

    @Test func extractsArchetypeKeywords() {
        let keys = DeckGeneratorCatalog.keywords(from: "Build me a Charizard ex deck")
        #expect(keys.contains("charizard"))
        #expect(!keys.contains("build"))
        #expect(!keys.contains("the"))
        #expect(!keys.contains("ex"))  // stopword — too generic
    }

    @Test func stripsApostropheS() {
        // Critical for Team Rocket's-style names — we want "rocket" not "rockets".
        let keys = DeckGeneratorCatalog.keywords(from: "Team Rocket's Articuno deck")
        #expect(keys.contains("rocket"))
        #expect(keys.contains("articuno"))
        #expect(keys.contains("team"))
    }

    @Test func dedupesKeywords() {
        let keys = DeckGeneratorCatalog.keywords(from: "Pikachu Pikachu Pikachu")
        #expect(keys == ["pikachu"])
    }

    @Test func ignoresShortTokens() {
        let keys = DeckGeneratorCatalog.keywords(from: "a b cd efg")
        #expect(!keys.contains("a"))
        #expect(!keys.contains("b"))
        #expect(!keys.contains("cd"))
        #expect(keys.contains("efg"))
    }

    @Test func emptyPromptYieldsNoKeywords() {
        #expect(DeckGeneratorCatalog.keywords(from: "").isEmpty)
        #expect(DeckGeneratorCatalog.keywords(from: "build me a deck").isEmpty)
    }

    // MARK: - Catalog filtering against a SwiftData store

    private func makeContext() throws -> ModelContext {
        let schema = Schema([CachedCard.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private func makeCard(name: String, setCode: String, number: String, supertype: String = "Pokémon", standard: Bool = true, release: Date = Date()) -> CachedCard {
        CachedCard(
            id: "\(setCode)-\(number)",
            name: name,
            supertype: supertype,
            setCode: setCode,
            setName: setCode,
            number: number,
            isStandardLegal: standard,
            imageURL: "",
            setReleaseDate: release
        )
    }

    @Test func returnsNilWhenNoKeywords() throws {
        let context = try makeContext()
        context.insert(makeCard(name: "Charizard ex", setCode: "OBF", number: "125"))
        let snippet = DeckGeneratorCatalog.candidatePokemon(for: "build me a deck", in: context)
        #expect(snippet == nil)
    }

    @Test func filtersByPromptKeyword() throws {
        let context = try makeContext()
        context.insert(makeCard(name: "Charizard ex", setCode: "OBF", number: "125"))
        context.insert(makeCard(name: "Pidgeot ex", setCode: "OBF", number: "164"))
        let snippet = try #require(DeckGeneratorCatalog.candidatePokemon(for: "Charizard ex deck", in: context))
        #expect(snippet.contains("Charizard ex"))
        #expect(!snippet.contains("Pidgeot"))
    }

    @Test func dedupesByNameKeepingMostRecentPrint() throws {
        let context = try makeContext()
        let old = Date(timeIntervalSince1970: 1_600_000_000)
        let new = Date(timeIntervalSince1970: 1_700_000_000)
        context.insert(makeCard(name: "Charizard ex", setCode: "OBF", number: "125", release: old))
        context.insert(makeCard(name: "Charizard ex", setCode: "PAF", number: "234", release: new))
        let snippet = try #require(DeckGeneratorCatalog.candidatePokemon(for: "Charizard deck", in: context))
        #expect(snippet.contains("PAF 234"))
        #expect(!snippet.contains("OBF 125"))
    }

    @Test func excludesNonStandardLegal() throws {
        let context = try makeContext()
        context.insert(makeCard(name: "Charizard ex", setCode: "OBF", number: "125", standard: true))
        context.insert(makeCard(name: "Charizard GX", setCode: "OLD", number: "1", standard: false))
        let snippet = try #require(DeckGeneratorCatalog.candidatePokemon(for: "Charizard deck", in: context))
        #expect(snippet.contains("Charizard ex"))
        #expect(!snippet.contains("Charizard GX"))
    }

    @Test func excludesTrainersAndEnergy() throws {
        let context = try makeContext()
        context.insert(makeCard(name: "Charizard ex", setCode: "OBF", number: "125"))
        context.insert(makeCard(name: "Charizard Trainer Charm", setCode: "XYZ", number: "1", supertype: "Trainer"))
        let snippet = try #require(DeckGeneratorCatalog.candidatePokemon(for: "Charizard deck", in: context))
        #expect(snippet.contains("Charizard ex"))
        #expect(!snippet.contains("Trainer Charm"))
    }
}

@Suite("DeckGeneratorValidator integration")
struct DeckGeneratorValidatorIntegrationTests {

    @Test func validDeckHasNoViolations() {
        let deck = """
        Pokémon: 4
        4 Charizard ex OBF 125

        Trainer: 52
        4 Iono PAL 185
        4 Boss's Orders PAL 172
        4 Professor's Research SVI 189
        4 Ultra Ball SVI 196
        4 Nest Ball PAF 84
        4 Buddy-Buddy Poffin TEF 223
        4 Rare Candy SVI 191
        4 Battle VIP Pass FST 225
        4 Switch SVI 194
        4 Earthen Vessel PAF 96
        4 Counter Catcher PAR 264
        4 Lost Vacuum LOR 217
        4 Pal Pad SVI 182

        Energy: 4
        4 Fire Energy SVE 2

        Total Cards: 60
        """
        // This particular composition has 13 trainer types of 4 = 52 trainers + 4 Pokémon + 4 Energy = 60.
        #expect(DeckGeneratorValidator.validate(deck).isEmpty)
    }

    @Test func flagsWrongTotalAndOverCopies() {
        let deck = """
        Pokémon: 12
        5 Charizard ex OBF 125
        4 Pidgey OBF 162
        3 Pidgeot ex OBF 164

        Trainer: 4
        4 Iono PAL 185

        Energy: 4
        4 Fire Energy SVE 2

        Total Cards: 20
        """
        let violations = DeckGeneratorValidator.validate(deck)
        #expect(violations.contains { if case .wrongTotal = $0.kind { true } else { false } })
        #expect(violations.contains { if case .exceeds4Copies(let name, _) = $0.kind { name == "Charizard ex" } else { false } })
    }
}
