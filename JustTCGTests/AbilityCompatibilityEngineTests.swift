import Testing
import Foundation
@testable import JustTCG

@Suite("AbilityCompatibilityEngine")
struct AbilityCompatibilityEngineTests {

    let engine = AbilityCompatibilityEngine()

    // MARK: - parseAbilities

    @Test func parseAbilitiesExtractsNameAndText() {
        let rulesText = ["[Ability] Power Saver\nThis Pokémon can't attack unless you have 4 or more Team Rocket's Pokémon in play."]
        let abilities = AbilityCompatibilityEngine.parseAbilities(from: rulesText)
        #expect(abilities.count == 1)
        #expect(abilities[0].name == "Power Saver")
        #expect(abilities[0].text.contains("4 or more Team Rocket's"))
    }

    @Test func parseAbilitiesSkipsAttacksAndRules() {
        let rulesText = [
            "[Ability] Flare Boost\nSome ability text.",
            "Flamethrower · 120\nDiscard an Energy from this Pokémon.",
            "This Pokémon can't use its attacks.",
        ]
        let abilities = AbilityCompatibilityEngine.parseAbilities(from: rulesText)
        #expect(abilities.count == 1)
        #expect(abilities[0].name == "Flare Boost")
    }

    @Test func parseAbilitiesHandlesPokemonPowerPrefix() {
        let rulesText = ["[Pokémon Power] Flare\nSome effect."]
        let abilities = AbilityCompatibilityEngine.parseAbilities(from: rulesText)
        #expect(abilities.count == 1)
        #expect(abilities[0].name == "Flare")
    }

    @Test func parseAbilitiesNoTextLine() {
        let rulesText = ["[Ability] Swift Swim"]
        let abilities = AbilityCompatibilityEngine.parseAbilities(from: rulesText)
        #expect(abilities.count == 1)
        #expect(abilities[0].text == "")
    }

    // MARK: - Type A: minimumInPlay detection

    @Test func detectsMinimumInPlay() {
        let conditions = engine.detectConditions(in: "This Pokémon can't attack unless you have 4 or more Team Rocket's Pokémon in play.")
        #expect(conditions.contains(.minimumInPlay(count: 4, qualifier: "Team Rocket's")))
    }

    @Test func detectsMinimumInPlayAtLeastVariant() {
        let conditions = engine.detectConditions(in: "If you have at least 2 Fire Pokémon in play, you may draw 2 cards.")
        #expect(conditions.contains(.minimumInPlay(count: 2, qualifier: "Fire")))
    }

    // MARK: - Type A: minimumInPlay scoring

    @Test func minimumInPlayScoreZeroWhenImpossible() {
        let entries = [
            DeckCardEntry(name: "Pikachu ex", copies: 4, supertype: "Pokémon", subtypes: ["Basic", "ex"])
        ]
        let s = engine.score(for: .minimumInPlay(count: 4, qualifier: "Team Rocket's"), in: entries)
        #expect(s == 0)
    }

    @Test func minimumInPlayScoreHighWithPlentyOfMatches() {
        // A real Team Rocket deck runs ~20 Team Rocket's Pokémon.
        // With 20 copies, desired=4, drawn=11: P ≥ ~0.45, score should be ≥ 65.
        var entries: [DeckCardEntry] = []
        for i in 1...10 {
            entries.append(DeckCardEntry(name: "Team Rocket's Mon \(i)", copies: 2, supertype: "Pokémon"))
        }
        let s = engine.score(for: .minimumInPlay(count: 4, qualifier: "Team Rocket's"), in: entries)
        #expect(s >= 65)
    }

    @Test func minimumInPlayUsesNamePrefix() {
        let entries = [
            DeckCardEntry(name: "Team Rocket's Mewtwo ex", copies: 4, supertype: "Pokémon"),
            DeckCardEntry(name: "Team Rocket's Moltres ex", copies: 2, supertype: "Pokémon"),
        ]
        let s = engine.score(for: .minimumInPlay(count: 4, qualifier: "Team Rocket's"), in: entries)
        #expect(s > 0)
    }

    // MARK: - Type B: namedCardRequired detection

    @Test func detectsNamedCardInPlay() {
        let conditions = engine.detectConditions(in: "Once during your turn, if you have Solrock in play, you may draw 3 cards.")
        #expect(conditions.contains(.namedCardRequired(cardName: "Solrock")))
    }

    @Test func detectsNamedCardWithAnyPrefix() {
        let conditions = engine.detectConditions(in: "If this Pokémon is Knocked Out, and if you have any Pecharunt ex in play, your opponent takes 1 fewer Prize card.")
        #expect(conditions.contains(.namedCardRequired(cardName: "Pecharunt Ex")))
    }

    @Test func namedCardScoresByCount() {
        let make = { (copies: Int) -> Int in
            let entries = copies == 0 ? [DeckCardEntry]() : [DeckCardEntry(name: "Solrock", copies: copies, supertype: "Pokémon")]
            return self.engine.score(for: .namedCardRequired(cardName: "Solrock"), in: entries)
        }
        #expect(make(0) == 0)
        #expect(make(1) == 40)
        #expect(make(2) == 65)
        #expect(make(3) == 85)
        #expect(make(4) == 100)
    }

    // MARK: - Type C: categoryPokemonRequired detection

    @Test func detectsTeraCategory() {
        let conditions = engine.detectConditions(in: "If you have any Tera Pokémon in play, you may search your deck.")
        #expect(conditions.contains(.categoryPokemonRequired(subtypeKeyword: "Tera", typeFilter: nil)))
    }

    @Test func detectsMegaEvolutionCategory() {
        let conditions = engine.detectConditions(in: "If you have any Mega Evolution Pokémon ex in play, switch this Pokémon.")
        #expect(conditions.contains(.categoryPokemonRequired(subtypeKeyword: "MEGA", typeFilter: nil)))
    }

    @Test func detectsFireMegaCategory() {
        let conditions = engine.detectConditions(in: "If you have any Fire Mega Evolution Pokémon ex in play, attach a Basic Fire Energy.")
        #expect(conditions.contains(.categoryPokemonRequired(subtypeKeyword: "MEGA", typeFilter: "Fire")))
    }

    @Test func detectsDarknessMegaCategory() {
        let conditions = engine.detectConditions(in: "If you have any Darkness Mega Evolution Pokémon ex in play, do 120 more damage.")
        #expect(conditions.contains(.categoryPokemonRequired(subtypeKeyword: "MEGA", typeFilter: "Darkness")))
    }

    @Test func categoryScoreFiveWhenNoneInDeck() {
        let entries = [DeckCardEntry(name: "Pikachu ex", copies: 4, supertype: "Pokémon", subtypes: ["Basic", "Tera", "ex"])]
        let s = engine.score(for: .categoryPokemonRequired(subtypeKeyword: "MEGA", typeFilter: nil), in: entries)
        #expect(s == 5)
    }

    @Test func categoryScoreHighWithTwoOrMoreMatches() {
        let entries = [
            DeckCardEntry(name: "Mega Pyroar ex", copies: 2, supertype: "Pokémon", subtypes: ["Stage 1", "MEGA", "ex"], types: ["Fire"]),
            DeckCardEntry(name: "Mega Charizard Y ex", copies: 2, supertype: "Pokémon", subtypes: ["Stage 2", "MEGA", "ex"], types: ["Fire"]),
        ]
        let s = engine.score(for: .categoryPokemonRequired(subtypeKeyword: "MEGA", typeFilter: "Fire"), in: entries)
        #expect(s == 90)
    }

    @Test func categoryScoreFiltersCorrectType() {
        let entries = [
            DeckCardEntry(name: "Mega Venusaur ex", copies: 2, supertype: "Pokémon", subtypes: ["Stage 2", "MEGA", "ex"], types: ["Grass"]),
        ]
        let s = engine.score(for: .categoryPokemonRequired(subtypeKeyword: "MEGA", typeFilter: "Fire"), in: entries)
        #expect(s == 5)
    }

    // MARK: - Type D: activationCost detection

    @Test func detectsActivationCostFireEnergy() {
        let conditions = engine.detectConditions(in: "You must discard a Basic Fire Energy card from your hand in order to use this Ability.")
        #expect(conditions.contains(.activationCost(cardPattern: "Basic Fire Energy", isEnergy: true)))
    }

    @Test func detectsActivationCostLightningEnergy() {
        let conditions = engine.detectConditions(in: "You must discard a Basic Lightning Energy from this Pokémon in order to use this Ability.")
        #expect(conditions.contains(.activationCost(cardPattern: "Basic Lightning Energy", isEnergy: true)))
    }

    @Test func detectsActivationCostItem() {
        let conditions = engine.detectConditions(in: "You must discard a Chill Teaser Toy card from your hand in order to use this Ability.")
        #expect(conditions.contains(.activationCost(cardPattern: "Chill Teaser Toy", isEnergy: false)))
    }

    @Test func genericDiscardIsUnconditional() {
        let conditions = engine.detectConditions(in: "You must discard a card from your hand in order to use this Ability. Once during your turn, draw 2 cards.")
        #expect(conditions == [.unconditional])
    }

    @Test func activationCostEnergyScoresByCount() {
        let condition = AbilityConditionType.activationCost(cardPattern: "Basic Fire Energy", isEnergy: true)
        let make = { (count: Int) -> [DeckCardEntry] in
            count == 0 ? [] : [DeckCardEntry(name: "Basic Fire Energy", copies: count, supertype: "Energy", subtypes: ["Basic"])]
        }
        #expect(engine.score(for: condition, in: make(0)) == 0)
        #expect(engine.score(for: condition, in: make(1)) == 40)
        #expect(engine.score(for: condition, in: make(3)) == 65)
        #expect(engine.score(for: condition, in: make(4)) == 100)
    }

    @Test func activationCostItemScoresByCount() {
        let condition = AbilityConditionType.activationCost(cardPattern: "Chill Teaser Toy", isEnergy: false)
        let make = { (count: Int) -> [DeckCardEntry] in
            count == 0 ? [] : [DeckCardEntry(name: "Chill Teaser Toy", copies: count, supertype: "Trainer", subtypes: ["Item"])]
        }
        #expect(engine.score(for: condition, in: make(0)) == 0)
        #expect(engine.score(for: condition, in: make(1)) == 60)
        #expect(engine.score(for: condition, in: make(2)) == 90)
    }

    // MARK: - Type E: trainerRequired detection

    @Test func detectsTrainerRequired() {
        let conditions = engine.detectConditions(in: "Once during your turn, if you played Janine's Secret Art from your hand this turn, you may draw cards.")
        #expect(conditions.contains(.trainerRequired(cardName: "Janine's Secret Art")))
    }

    @Test func detectsTrainerRequiredCanari() {
        let conditions = engine.detectConditions(in: "Once during your turn, if you played Canari from your hand this turn, search your deck.")
        #expect(conditions.contains(.trainerRequired(cardName: "Canari")))
    }

    @Test func trainerRequiredScoreZeroWhenMissing() {
        let entries = [DeckCardEntry(name: "Professor's Research", copies: 4, supertype: "Trainer")]
        let s = engine.score(for: .trainerRequired(cardName: "Janine's Secret Art"), in: entries)
        #expect(s == 0)
    }

    // MARK: - Type F: selfEnergyRequired detection

    @Test func detectsSelfEnergyDarkness() {
        let conditions = engine.detectConditions(in: "Once during your turn, if this Pokémon has any Darkness Energy attached, you may move up to 3 damage counters.")
        #expect(conditions.contains(.selfEnergyRequired(energyType: "Darkness")))
    }

    @Test func detectsSelfEnergySpecial() {
        let conditions = engine.detectConditions(in: "If this Pokémon has any Special Energy attached, it gets +150 HP.")
        #expect(conditions.contains(.selfEnergyRequired(energyType: "Special")))
    }

    @Test func selfEnergyScoreZeroWhenNoEnergyInDeck() {
        let entries = [DeckCardEntry(name: "Munkidori", copies: 2, supertype: "Pokémon", hasAbility: true)]
        let s = engine.score(for: .selfEnergyRequired(energyType: "Darkness"), in: entries)
        #expect(s == 0)
    }

    @Test func selfEnergyScoreHighWithFourEnergy() {
        let entries = [
            DeckCardEntry(name: "Basic Darkness Energy", copies: 4, supertype: "Energy", subtypes: ["Basic"]),
        ]
        let s = engine.score(for: .selfEnergyRequired(energyType: "Darkness"), in: entries)
        #expect(s == 100)
    }

    @Test func selfEnergySpecialScoresByCount() {
        let condition = AbilityConditionType.selfEnergyRequired(energyType: "Special")
        let make = { (count: Int) -> [DeckCardEntry] in
            count == 0 ? [] : [DeckCardEntry(name: "Double Turbo Energy", copies: count, supertype: "Energy", subtypes: ["Special"])]
        }
        #expect(engine.score(for: condition, in: make(0)) == 0)
        #expect(engine.score(for: condition, in: make(1)) == 55)
        #expect(engine.score(for: condition, in: make(2)) == 80)
    }

    // MARK: - Compound conditions (synthetic: named card + must-discard energy)

    @Test func compoundConditionTakesMinimumScore() {
        // Synthetic text with both Type B (named card) and Type D (must-discard energy)
        let syntheticText = "Once during your turn, if you have Solrock in play, you must discard a Basic Fighting Energy from your hand in order to use this Ability. Draw 3 cards."
        let entries = [
            DeckCardEntry(name: "Solrock", copies: 2, supertype: "Pokémon"),
            // No Fighting Energy → Type D score = 0
        ]
        let conditions = engine.detectConditions(in: syntheticText)
        #expect(conditions.count >= 2)

        let scores = conditions.map { engine.score(for: $0, in: entries) }
        #expect(scores.contains(0))   // Fighting Energy missing → score 0
        #expect(scores.min() == 0)    // compound score is min of all
    }

    // MARK: - Non-compat conditions are unconditional

    @Test func positionConditionIsUnconditional() {
        let conditions = engine.detectConditions(in: "Once during your turn, if this Pokémon is in the Active Spot, you may draw 2 cards.")
        #expect(conditions == [.unconditional])
    }

    @Test func oncePerTurnIsUnconditional() {
        let conditions = engine.detectConditions(in: "Once during your turn, you may draw a card.")
        #expect(conditions == [.unconditional])
    }

    // MARK: - Deck-level breakdown

    @Test func deckScoreIs100WithNoAbilityPokemon() {
        let entries = [DeckCardEntry(name: "Professor's Research", copies: 4, supertype: "Trainer")]
        let breakdown = engine.breakdown(entries: entries, abilityTexts: { _ in [] })
        #expect(breakdown.compatibilityScore == 100)
        #expect(breakdown.results.isEmpty)
    }

    @Test func deckScoreDeductsPerConflict() {
        // Team Rocket's Mewtwo ex with 0 Team Rocket's Pokémon → conflict (score 0, −30)
        let entries = [
            DeckCardEntry(name: "Team Rocket's Mewtwo ex", copies: 2, supertype: "Pokémon", hasAbility: true),
            DeckCardEntry(name: "Pikachu ex", copies: 4, supertype: "Pokémon"),
        ]
        let breakdown = engine.breakdown(entries: entries) { name in
            name == "Team Rocket's Mewtwo ex"
                ? [("Power Saver", "This Pokémon can't attack unless you have 4 or more Team Rocket's Pokémon in play.")]
                : []
        }
        #expect(breakdown.conflicts.count == 1)
        #expect(breakdown.compatibilityScore == 70)
    }

    @Test func deckScoreClampedToZero() {
        var entries: [DeckCardEntry] = []
        var textMap: [String: [(name: String, text: String)]] = [:]
        for i in 1...4 {
            let name = "Conflict Mon \(i)"
            entries.append(DeckCardEntry(name: name, copies: 1, supertype: "Pokémon", hasAbility: true))
            textMap[name] = [("Bad Ability", "This Pokémon can't attack unless you have 4 or more Team Rocket's Pokémon in play.")]
        }
        let breakdown = engine.breakdown(entries: entries) { name in textMap[name] ?? [] }
        #expect(breakdown.compatibilityScore == 0)
    }

    @Test func resultsAreSortedByScoreAscending() {
        let entries = [
            DeckCardEntry(name: "A", copies: 1, supertype: "Pokémon", hasAbility: true),
            DeckCardEntry(name: "B", copies: 1, supertype: "Pokémon", hasAbility: true),
        ]
        // A: namedCard with 0 copies → score 0
        // B: category with 0 matches → score 5
        let textMap: [String: [(name: String, text: String)]] = [
            "A": [("Ability A", "If you have Solrock in play, draw 2 cards.")],
            "B": [("Ability B", "If you have any Tera Pokémon in play, draw 1 card.")],
        ]
        let breakdown = engine.breakdown(entries: entries) { name in textMap[name] ?? [] }
        let scores = breakdown.results.map(\.score)
        #expect(scores == scores.sorted())
        #expect(scores.first == 0)
    }

    @Test func warningIsNilForUnconditionalAbility() {
        let entries = [
            DeckCardEntry(name: "Bibarel", copies: 2, supertype: "Pokémon", hasAbility: true),
        ]
        let breakdown = engine.breakdown(entries: entries) { _ in
            [("Industrious Incisors", "Once during your turn, you may draw cards until you have 5 cards in your hand.")]
        }
        #expect(breakdown.results.first?.severity == .ok)
        #expect(breakdown.results.first?.warningMessage == nil)
    }

    @Test func warningIsPresentForConflict() {
        let entries = [
            DeckCardEntry(name: "Team Rocket's Mewtwo ex", copies: 2, supertype: "Pokémon", hasAbility: true),
        ]
        let breakdown = engine.breakdown(entries: entries) { _ in
            [("Power Saver", "This Pokémon can't attack unless you have 4 or more Team Rocket's Pokémon in play.")]
        }
        let result = breakdown.results.first
        #expect(result?.severity == .conflict)
        #expect(result?.warningMessage != nil)
        #expect(result?.warningMessage?.contains("Power Saver") == true)
    }
}
