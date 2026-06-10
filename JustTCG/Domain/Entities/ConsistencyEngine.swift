import Foundation

struct DeckCardEntry {
    let name: String
    let copies: Int
    var supertype: String = ""
    var subtypes: [String] = []
    var retreatCost: Int? = nil
    var imageURL: String? = nil
    var hasAbility: Bool = false
    /// Pokémon energy type(s) (e.g. ["Fire"]) or Energy card types. Empty for Trainers.
    var types: [String] = []
    /// The type this Pokémon is weak to (e.g. "Fire"). Nil for Trainers, Energy, or unknown.
    var weaknessType: String? = nil
    /// User-assigned role: `.attacker` (needs energy to attack) or `.tech` (ability-only, no energy needed).
    /// Nil means unassigned — the engine applies a heuristic.
    var pokemonRole: PokemonRole? = nil
    /// Minimum number of energy attachments required to use any attack. Nil for non-Pokémon or unknown.
    var minAttackCost: Int? = nil
}

struct KeyCardOdds {
    let name: String
    let copies: Int
    let imageURL: String?
    let openingHandProbability: Double
    let byTurn2First: Double
    let byTurn2Second: Double
}

struct ConsistencyBreakdown {
    let overallScore: Int
    let consistencyScore: Int
    let drawCount: Int
    let searchCount: Int
    let basicOpeningHandProbability: Double
    let abilityImpactScore: Int
    let energyScore: Int
    let energyAccelCount: Int
    let energyCardCount: Int
    /// Number of Pokémon copies identified as attackers (labeled or by heuristic).
    let identifiedAttackerCopies: Int
    /// Average minimum attack cost across identified attackers. Nil when no attackers identified.
    let attackerAvgMinCost: Double?
    /// Number of Pokémon that are Pokémon-type but have no role label assigned.
    let unlabeledPokemonCount: Int
    let prizeResilienceScore: Int
    let disruptionScore: Int
    let evolutionScore: Int
    let recoveryScore: Int
    let itemDependencyScore: Int
    let mobilityScore: Int
    let keyCards: [KeyCardOdds]
}

struct ConsistencyEngine {

    // MARK: - Hypergeometric math

    private static func logBinomial(_ n: Int, _ k: Int) -> Double {
        guard k >= 0, k <= n else { return -Double.infinity }
        return lgamma(Double(n + 1)) - lgamma(Double(k + 1)) - lgamma(Double(n - k + 1))
    }

    private static func hypergeometricPMF(N: Int, K: Int, n: Int, k: Int) -> Double {
        let logP = logBinomial(K, k) + logBinomial(N - K, n - k) - logBinomial(N, n)
        return exp(logP)
    }

    /// P(X ≥ desired) using exact hypergeometric CDF.
    static func probabilityAtLeast(copies: Int, deckSize: Int, drawn: Int, desired: Int) -> Double {
        guard desired > 0 else { return 1.0 }
        guard copies > 0, drawn > 0, deckSize > 0 else { return 0.0 }
        var cdfBelow = 0.0
        for k in 0 ..< desired {
            cdfBelow += hypergeometricPMF(N: deckSize, K: copies, n: drawn, k: k)
        }
        return max(0.0, min(1.0, 1.0 - cdfBelow))
    }

    /// P(≥1 copy in opening 7).
    static func openingHandProbability(copies: Int, deckSize: Int) -> Double {
        probabilityAtLeast(copies: copies, deckSize: deckSize, drawn: 7, desired: 1)
    }

    /// P(having drawn ≥1 copy by the start of turn N).
    /// Going first draws 7 + (N − 1); going second draws 7 + N.
    static func probabilityByTurn(copies: Int, deckSize: Int, turn: Int) -> (first: Double, second: Double) {
        let drawnFirst  = 7 + (turn - 1)
        let drawnSecond = 7 + turn
        return (
            first:  probabilityAtLeast(copies: copies, deckSize: deckSize, drawn: drawnFirst,  desired: 1),
            second: probabilityAtLeast(copies: copies, deckSize: deckSize, drawn: drawnSecond, desired: 1)
        )
    }

    // MARK: - Consistency score

    func consistencyScore(cards: [DeckCardEntry], roleTags: (String) -> [String]) -> Int {
        var drawCount   = 0
        var searchCount = 0
        for entry in cards {
            let tags = roleTags(entry.name)
            if tags.contains("Draw")   { drawCount   += entry.copies }
            if tags.contains("Search") { searchCount += entry.copies }
        }
        let cappedDraw   = min(drawCount,   14)
        let cappedSearch = min(searchCount, 12)
        return min(100, (cappedDraw + cappedSearch) * 5)
    }

    // MARK: - Full breakdown

    func breakdown(entries: [DeckCardEntry], deckSize: Int = 60, roleTags: (String) -> [String]) -> ConsistencyBreakdown {
        var drawCount        = 0
        var searchCount      = 0
        var abilityImpactRaw = 0
        var energyAccelCount = 0
        var energyCardCount  = 0
        var disruptionCount   = 0
        var recoveryCount     = 0
        var mobilityTagCount  = 0
        var totalRetreatCost  = 0
        var pokemonWithRetreat = 0
        var singlePrizeCopies = 0
        var rulePokemonCopies = 0
        var basicPokeCopies  = 0
        var stage1Copies     = 0
        var stage2Copies     = 0
        var rareCandyCopies  = 0
        var itemCopies       = 0
        var supporterCopies  = 0

        let ruleBoxSubtypes: Set<String> = ["ex", "V", "VSTAR", "VMAX", "GX", "VUNION"]

        for entry in entries {
            let tags = roleTags(entry.name)
            if tags.contains("Draw")               { drawCount        += entry.copies }
            if tags.contains("Search")             { searchCount      += entry.copies }
            if tags.contains("Energy Acceleration") { energyAccelCount += entry.copies }
            if tags.contains("Disruption")         { disruptionCount  += entry.copies }
            if tags.contains("Recovery")           { recoveryCount    += entry.copies }
            if tags.contains("Mobility")           { mobilityTagCount += entry.copies }
            if entry.supertype == "Energy"         { energyCardCount  += entry.copies }
            if entry.supertype == "Pokémon", let rc = entry.retreatCost {
                totalRetreatCost  += rc * entry.copies
                pokemonWithRetreat += entry.copies
            }

            if entry.supertype == "Pokémon" {
                if entry.hasAbility {
                    // Ability Impact: weight each role tag by competitive value, cap per card
                    let abilityTagImpact: [String: Int] = [
                        "Draw": 4, "Search": 4,
                        "Energy Acceleration": 3, "Prize Control": 3, "Lock": 3,
                        "Disruption": 2, "Recovery": 2, "Survivability": 2,
                        "Mobility": 1, "Healing": 1, "Damage Boost": 1, "Damage Reduction": 1,
                    ]
                    let cardImpact = min(5, abilityTagImpact.reduce(0) { acc, kv in
                        tags.contains(kv.key) ? acc + kv.value : acc
                    })
                    abilityImpactRaw += min(3, entry.copies) * cardImpact
                }
                if !Set(entry.subtypes).isDisjoint(with: ruleBoxSubtypes) {
                    rulePokemonCopies += entry.copies
                } else {
                    singlePrizeCopies += entry.copies
                }
                if entry.subtypes.contains("Basic")   { basicPokeCopies += entry.copies }
                if entry.subtypes.contains("Stage 1") { stage1Copies    += entry.copies }
                if entry.subtypes.contains("Stage 2") { stage2Copies    += entry.copies }
            }

            if entry.name == "Rare Candy" { rareCandyCopies += entry.copies }

            if entry.supertype == "Trainer" {
                if entry.subtypes.contains("Item")      { itemCopies      += entry.copies }
                if entry.subtypes.contains("Supporter") { supporterCopies += entry.copies }
            }
        }

        let score              = min(100, (min(drawCount, 14) + min(searchCount, 12)) * 5)
        // abilityImpactRaw: 3 copies × 5 pts = 15 per card; ×4 → 60 for one dominant card,
        // 100 requires two or more high-impact ability lines.
        let abilityImpactScore = min(100, abilityImpactRaw * 4)

        // --- Attacker-aware energy score ---
        // Heuristic: only the highest-stage unlabeled Pokémon (with attacks) count toward energy demand.
        // Explicit role labels override the heuristic: `.attacker` always included, `.tech` always excluded.
        let hasStage2 = entries.contains { $0.supertype == "Pokémon" && $0.subtypes.contains("Stage 2") }
        let hasStage1 = entries.contains { $0.supertype == "Pokémon" && $0.subtypes.contains("Stage 1") }

        var attackerCopies = 0
        var weightedCostSum = 0.0
        var unlabeledPokemonCount = 0
        for entry in entries where entry.supertype == "Pokémon" {
            if entry.pokemonRole == nil { unlabeledPokemonCount += entry.copies }
            let isAttacker: Bool
            switch entry.pokemonRole {
            case .attacker:
                isAttacker = true
            case .tech:
                isAttacker = false
            case nil:
                // Include only the highest evolution stage that has real attacks.
                let isTopStage: Bool
                if hasStage2 {
                    isTopStage = entry.subtypes.contains("Stage 2")
                } else if hasStage1 {
                    isTopStage = entry.subtypes.contains("Stage 1")
                } else {
                    isTopStage = true
                }
                isAttacker = isTopStage && (entry.minAttackCost ?? 0) > 0
            }
            if isAttacker {
                attackerCopies += entry.copies
                weightedCostSum += Double(entry.copies) * Double(entry.minAttackCost ?? 2)
            }
        }

        let energyScore: Int
        let attackerAvgMinCost: Double?
        if attackerCopies > 0 {
            let avgCost = weightedCostSum / Double(attackerCopies)
            attackerAvgMinCost = avgCost
            let demand = Double(attackerCopies) * avgCost
            let supply = Double(energyCardCount) + Double(energyAccelCount) * 2.0
            // Full base score (80 pts) when supply is 1.5× demand; accel gives up to 20 bonus pts.
            let ratio = supply / max(1.0, demand)
            let baseScore = Int(min(1.0, ratio / 1.5) * 80)
            let accelBonus = min(20, energyAccelCount * 5)
            energyScore = min(100, baseScore + accelBonus)
        } else {
            // No attackers identified — fall back to raw card-count heuristic.
            attackerAvgMinCost = nil
            energyScore = min(100, min(energyAccelCount, 6) * 10 + min(energyCardCount, 15) * 4)
        }

        let totalPokemon = singlePrizeCopies + rulePokemonCopies
        let prizeResilienceScore = totalPokemon == 0 ? 50 : singlePrizeCopies * 100 / totalPokemon

        let disruptionScore = min(100, min(disruptionCount, 10) * 10)

        let evolutionScore: Int
        if stage1Copies == 0 && stage2Copies == 0 {
            evolutionScore = 100
        } else if stage2Copies == 0 {
            // Stage 1 deck: want ≥1.5× basics per stage 1
            let ratio = Double(basicPokeCopies) / (Double(stage1Copies) * 1.5)
            evolutionScore = min(100, Int(ratio * 100))
        } else {
            // Stage 2 deck: basics + middle layer (stage 1 or rare candy) each scored /50
            let middleLayer = stage1Copies + rareCandyCopies
            let basicScore  = min(50, Int(Double(basicPokeCopies) / (Double(stage2Copies) * 1.5) * 50))
            let middleScore = min(50, Int(Double(middleLayer)      / (Double(stage2Copies) * 1.5) * 50))
            evolutionScore  = basicScore + middleScore
        }

        let recoveryScore = min(100, min(recoveryCount, 8) * 12)

        let totalTrainers = itemCopies + supporterCopies
        let itemDependencyScore = totalTrainers == 0 ? 0 : itemCopies * 100 / totalTrainers

        // Mobility: switching cards/abilities (50 pts) + low retreat cost (50 pts)
        let avgRetreat   = pokemonWithRetreat == 0 ? 0.0 : Double(totalRetreatCost) / Double(pokemonWithRetreat)
        let cardScore    = min(50, mobilityTagCount * 7)
        let retreatScore = max(0, 50 - Int(avgRetreat * 15.0))
        let mobilityScore = min(100, cardScore + retreatScore)

        let keyCards: [KeyCardOdds] = entries
            .sorted {
                $0.copies != $1.copies ? $0.copies > $1.copies : $0.name < $1.name
            }
            .map { entry in
                let t2 = Self.probabilityByTurn(copies: entry.copies, deckSize: deckSize, turn: 2)
                return KeyCardOdds(
                    name: entry.name,
                    copies: entry.copies,
                    imageURL: entry.imageURL,
                    openingHandProbability: Self.openingHandProbability(copies: entry.copies, deckSize: deckSize),
                    byTurn2First:  t2.first,
                    byTurn2Second: t2.second
                )
            }

        // Weighted composite: consistency 28%, evolution 18%, energy 13%,
        // ability impact 9%, prize resilience 9%, disruption 8%, recovery 8%, mobility 7%
        let overallScore = (
            score                * 28 +
            evolutionScore       * 18 +
            energyScore          * 13 +
            abilityImpactScore   *  9 +
            prizeResilienceScore *  9 +
            disruptionScore      *  8 +
            recoveryScore        *  8 +
            mobilityScore        *  7
        ) / 100

        let basicOpeningHandProbability = Self.openingHandProbability(copies: basicPokeCopies, deckSize: deckSize)

        return ConsistencyBreakdown(
            overallScore: overallScore,
            consistencyScore: score,
            drawCount: drawCount,
            searchCount: searchCount,
            basicOpeningHandProbability: basicOpeningHandProbability,
            abilityImpactScore: abilityImpactScore,
            energyScore: energyScore,
            energyAccelCount: energyAccelCount,
            energyCardCount: energyCardCount,
            identifiedAttackerCopies: attackerCopies,
            attackerAvgMinCost: attackerAvgMinCost,
            unlabeledPokemonCount: unlabeledPokemonCount,
            prizeResilienceScore: prizeResilienceScore,
            disruptionScore: disruptionScore,
            evolutionScore: evolutionScore,
            recoveryScore: recoveryScore,
            itemDependencyScore: itemDependencyScore,
            mobilityScore: mobilityScore,
            keyCards: keyCards
        )
    }
}
