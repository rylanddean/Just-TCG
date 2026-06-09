import Testing
import Foundation
@testable import JustTCG

@Suite("MetaMatchupEngine")
struct MetaMatchupEngineTests {

    let engine = MetaMatchupEngine()

    private func shares(_ pairs: [(String, Double)]) -> [ArchetypeShare] {
        pairs.map { ArchetypeShare(id: UUID(), archetypeName: $0.0, sharePercent: $0.1) }
    }

    // MARK: - Standard type advantage

    @Test func fireAttackersFavouredAgainstGrass() {
        // Grass is weak to Fire; user has Fire attackers
        let deck = [DeckCardEntry(name: "Charizard ex", copies: 3, supertype: "Pokémon", types: ["Fire"])]
        let meta = shares([("Ogerpon Meganium", 15.0)])
        let result = engine.breakdown(deck: deck, metaShares: meta)
        #expect(result.matchups.first?.advantage == .favoured)
        #expect(result.matchupScore == 100)
    }

    @Test func waterAttackersUnfavouredAgainstLightning() {
        // Lightning is weak to Fighting, not Water; user's Water Pokémon are weak to Lightning
        let deck = [DeckCardEntry(name: "Greninja ex", copies: 3, supertype: "Pokémon",
                                  types: ["Water"], weaknessType: "Lightning")]
        let meta = shares([("Raging Bolt ex", 18.0)])
        let result = engine.breakdown(deck: deck, metaShares: meta)
        #expect(result.matchups.first?.advantage == .unfavoured)
        #expect(result.matchupScore == 0)
    }

    // MARK: - Ability-based type advantage

    @Test func fairyZoneGrantsColorlessAdvantageAgainstPsychicWeak() {
        // Dragapult ex is Psychic type → weak to Darkness (per weakness chart).
        // Fairy Zone extends Darkness-weakness to Colorless.
        // User has Colorless attackers + Lillie's Clefairy ex (has ability) → Favoured.
        let deck = [
            DeckCardEntry(name: "Lillie's Clefairy ex", copies: 2, supertype: "Pokémon",
                          types: ["Colorless"], hasAbility: true),
            DeckCardEntry(name: "Clefairy", copies: 4, supertype: "Pokémon",
                          types: ["Colorless"])
        ]
        let meta = shares([("Dragapult ex", 20.0)])
        let result = engine.breakdown(deck: deck, metaShares: meta)
        let entry = result.matchups.first
        #expect(entry?.advantage == .favoured)
        #expect(entry?.abilitySource == "Lillie's Clefairy ex — Fairy Zone")
    }

    @Test func noAbilityNoFairyZoneBoost() {
        // Same deck but without Lillie's Clefairy ex having an ability → not favoured via Fairy Zone
        let deck = [
            DeckCardEntry(name: "Clefairy", copies: 4, supertype: "Pokémon",
                          types: ["Colorless"], hasAbility: false)
        ]
        let meta = shares([("Dragapult ex", 20.0)])
        let result = engine.breakdown(deck: deck, metaShares: meta)
        #expect(result.matchups.first?.advantage != .favoured)
    }

    // MARK: - Edge cases

    @Test func emptyMetaSharesReturnsScore50() {
        let deck = [DeckCardEntry(name: "Pikachu ex", copies: 4, supertype: "Pokémon", types: ["Lightning"])]
        let result = engine.breakdown(deck: deck, metaShares: [])
        #expect(result.matchupScore == 50)
        #expect(result.matchups.isEmpty)
    }

    @Test func weightedScoreHigherWhenFavouredArchetypesHaveMoreShare() {
        let deck = [DeckCardEntry(name: "Charizard ex", copies: 3, supertype: "Pokémon", types: ["Fire"])]
        // Grass weak to Fire (favoured), Water weak to Lightning (even for Fire attacker)
        let highFireShare = shares([("Ogerpon Meganium", 30.0), ("Greninja ex", 5.0)])
        let lowFireShare  = shares([("Ogerpon Meganium", 5.0),  ("Greninja ex", 30.0)])
        let highResult = engine.breakdown(deck: deck, metaShares: highFireShare)
        let lowResult  = engine.breakdown(deck: deck, metaShares: lowFireShare)
        #expect(highResult.matchupScore > lowResult.matchupScore)
    }

    @Test func evenMatchupScores50() {
        // No type advantage or disadvantage
        let deck = [DeckCardEntry(name: "Mew ex", copies: 3, supertype: "Pokémon", types: ["Psychic"])]
        // Psychic is weak to Darkness; Charizard ex is Fire (weak to Water, not Psychic) → even
        let meta = shares([("Charizard ex", 20.0)])
        let result = engine.breakdown(deck: deck, metaShares: meta)
        // Charizard ex is Fire type; Psychic attackers don't hit Fire weakness (Fire is weak to Water)
        // User's Psychic Pokémon weakness not set → not unfavoured either
        #expect(result.matchups.first?.advantage == .even)
        #expect(result.matchupScore == 50)
    }
}
