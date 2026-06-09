import Testing
import Foundation
@testable import JustTCG

@Suite("ArchetypePrimaryCardResolver")
struct ArchetypePrimaryCardResolverTests {

    let resolver = ArchetypePrimaryCardResolver()

    private func makeCard(id: String = UUID().uuidString, name: String, supertype: String = "Pokémon") -> CachedCard {
        CachedCard(id: id, name: name, supertype: supertype, setCode: "TST", setName: "Test", number: "001", imageURL: "")
    }

    @Test func exactMatch() {
        let cards = [makeCard(name: "Charizard ex"), makeCard(name: "Pidgeot ex")]
        let result = resolver.resolve(archetype: "Charizard ex", from: cards)
        #expect(result?.name == "Charizard ex")
    }

    @Test func slashSplitArchetype() {
        let cards = [makeCard(name: "Dragapult ex"), makeCard(name: "Pidgeot ex")]
        let result = resolver.resolve(archetype: "Dragapult ex / Pidgeot ex", from: cards)
        #expect(result?.name == "Dragapult ex")
    }

    @Test func prefixMatch() {
        let cards = [makeCard(name: "Miraidon ex")]
        let result = resolver.resolve(archetype: "Miraidon", from: cards)
        #expect(result != nil)
    }

    @Test func noMatchReturnsNil() {
        let cards = [makeCard(name: "Pikachu")]
        let result = resolver.resolve(archetype: "Snorlax ex", from: cards)
        #expect(result == nil)
    }

    @Test func nonPokemonExcluded() {
        let trainerCard = makeCard(name: "Professor's Research", supertype: "Trainer")
        let energyCard  = makeCard(name: "Basic Fire Energy", supertype: "Energy")
        let result = resolver.resolve(archetype: "Professor's Research", from: [trainerCard, energyCard])
        #expect(result == nil)
    }

    @Test func caseInsensitiveMatch() {
        let cards = [makeCard(name: "Gardevoir ex")]
        let result = resolver.resolve(archetype: "GARDEVOIR EX", from: cards)
        #expect(result?.name == "Gardevoir ex")
    }
}
