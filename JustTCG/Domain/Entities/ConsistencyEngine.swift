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
    /// Cards that force the opponent's Active Pokémon to change (Boss's Orders, Counter Catcher, etc.).
    /// Score: min(gustingCount, 5) × 20 — a full playset of 4 Boss's Orders scores 80.
    let gustingScore: Int
    let evolutionScore: Int
    let recoveryScore: Int
    let itemDependencyScore: Int
    let mobilityScore: Int
    let keyCards: [KeyCardOdds]

    // ── New axes (BUG-35) ────────────────────────────────────────────────────
    /// Probability (0–100) of being able to attack on turn 2 going second.
    /// Models P(≥1 attacker) × P(energy ready) over an effective hand size that accounts for
    /// draw supporters (Lillie's Determination, Cynthia, etc.) and search supporters (Hilda,
    /// Arven, etc.) you can play on T1 or T2 to access more of your deck.
    let turnTwoAggressionScore: Int
    /// How few prizes the deck gives up on average per Pokémon KO (0–100).
    /// Single-prize only → 100; mixed 2-prize → 50; VMAX/VSTAR-heavy → lower.
    let prizeEfficiencyScore: Int
    /// How many of the 5 bench slots remain after dedicated engine Pokémon (0–100).
    /// Each distinct Pokémon with a bench-sitting ability role costs 20 pts.
    let benchFlexibilityScore: Int
    /// Probability (0–100) of not mulliganing: P(≥1 Basic Pokémon in opening 7).
    let openingReliabilityScore: Int
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
        var gustingCount      = 0
        var recoveryCount     = 0
        var mobilityTagCount  = 0
        var totalRetreatCost  = 0
        var pokemonWithRetreat = 0
        var singlePrizeCopies = 0
        var rulePokemonCopies = 0
        var basicPokeCopies  = 0
        var stage1Copies     = 0
        var stage2Copies     = 0
        var rareCandyCopies      = 0
        var itemCopies           = 0
        var supporterCopies      = 0
        var drawSupporterCopies  = 0
        var searchSupporterCopies = 0

        let ruleBoxSubtypes: Set<String> = ["ex", "V", "VSTAR", "VMAX", "GX", "VUNION"]

        for entry in entries {
            let tags = roleTags(entry.name)
            if tags.contains("Draw")               { drawCount        += entry.copies }
            if tags.contains("Search")             { searchCount      += entry.copies }
            if tags.contains("Energy Acceleration") { energyAccelCount += entry.copies }
            if tags.contains("Disruption")         { disruptionCount  += entry.copies }
            if tags.contains("Gusting")            { gustingCount     += entry.copies }
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
                if entry.subtypes.contains("Supporter") {
                    supporterCopies += entry.copies
                    if tags.contains("Draw")   { drawSupporterCopies   += entry.copies }
                    if tags.contains("Search") { searchSupporterCopies += entry.copies }
                }
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

        // ── New axes ─────────────────────────────────────────────────────────

        // Turn-2 Aggression: P(attacker in hand) × P(energy ready) by T2 going second.
        // Going second, T2 start = 7 opening + T1 draw + T2 draw = 9 cards seen naturally.
        //
        // Two supporter layers model the cards that help you set up on T1/T2:
        //
        // 1. Draw supporters (Lillie's Determination, Cynthia, Professor's Research, etc.)
        //    expand the random pool: holding one lets you see ~3 more cards, so their
        //    expected contribution is added to t2EffectiveDraw.
        //
        // 2. Search supporters (Hilda, Arven, etc.) are treated differently — they do not
        //    just add random cards, they GUARANTEE a specific card still in the deck.
        //    Modeled as a parallel success path:
        //      P(ready) = 1 − P(miss naturally) × P(search also fails to cover)
        //    Confidence weights reflect that not every search supporter can find any card:
        //      Attacker (a Pokémon) → 0.8  — most search supporters can find a Pokémon
        //      Energy              → 0.5  — fewer can find basic Energy cards
        //
        // Energy model: 2 natural attachment slots exist by T2 (one on T1, one on T2).
        // Manual energy cards cover the first min(minCost, 2) of those slots.
        // Acceleration cards cover any cost above 2; each counts as one extra attachment.
        let t2Drawn        = 9
        let t2AttackerPool = attackerCopies > 0 ? attackerCopies : basicPokeCopies
        let t2MinCost      = attackerAvgMinCost.map { Int(ceil($0)) } ?? 1

        let pHaveDrawSupporter   = Self.probabilityAtLeast(copies: drawSupporterCopies,   deckSize: deckSize, drawn: t2Drawn, desired: 1)
        let pHaveSearchSupporter = Self.probabilityAtLeast(copies: searchSupporterCopies, deckSize: deckSize, drawn: t2Drawn, desired: 1)

        // Draw supporters widen the random pool; search supporters are handled via guarantee below.
        let supporterBonus  = pHaveDrawSupporter * 3.0
        let t2EffectiveDraw = min(deckSize - 1, t2Drawn + Int(supporterBonus.rounded()))

        let manualNeeded = min(t2MinCost, 2)    // covered by natural attachments
        let accelNeeded  = max(0, t2MinCost - 2) // extra cost requiring accel

        // Search guarantee paths — major score buff when search can cover the missing piece.
        let searchAttackerCoverage = t2AttackerPool > 0 ? pHaveSearchSupporter * 0.8 : 0.0
        let searchEnergyCoverage   = energyCardCount > 0 && manualNeeded > 0 ? pHaveSearchSupporter * 0.5 : 0.0

        let pT2AttackerBase = Self.probabilityAtLeast(copies: t2AttackerPool, deckSize: deckSize, drawn: t2EffectiveDraw, desired: 1)
        let pT2Attacker     = 1.0 - (1.0 - pT2AttackerBase) * (1.0 - searchAttackerCoverage)

        let pManualBase = Self.probabilityAtLeast(copies: energyCardCount, deckSize: deckSize, drawn: t2EffectiveDraw, desired: manualNeeded)
        let pManual     = manualNeeded == 0 ? 1.0
            : 1.0 - (1.0 - pManualBase) * (1.0 - searchEnergyCoverage)

        let pAccel    = accelNeeded == 0 ? 1.0
            : Self.probabilityAtLeast(copies: energyAccelCount, deckSize: deckSize, drawn: t2EffectiveDraw, desired: accelNeeded)
        let pT2Energy = pManual * pAccel
        let turnTwoAggressionScore = min(100, Int(pT2Attacker * pT2Energy * 100))

        // Prize Efficiency: weighted avg prizes given up per Pokémon KO, mapped to 0–100.
        // VMAX / VSTAR → 3 prizes; ex / V / GX / VUNION → 2; everything else → 1.
        var totalPrizeWeight = 0
        var totalPokeCopies  = 0
        for entry in entries where entry.supertype == "Pokémon" {
            let subs = Set(entry.subtypes)
            let pv: Int
            if subs.contains("VMAX") || subs.contains("VSTAR") { pv = 3 }
            else if subs.contains("ex") || subs.contains("V") || subs.contains("GX") || subs.contains("VUNION") { pv = 2 }
            else { pv = 1 }
            totalPrizeWeight += pv * entry.copies
            totalPokeCopies  += entry.copies
        }
        let avgPrizes = totalPokeCopies > 0 ? Double(totalPrizeWeight) / Double(totalPokeCopies) : 1.0
        // avg=1 → 100, avg=2 → 50, avg=3 → 0
        let prizeEfficiencyScore = max(0, min(100, Int((3.0 - avgPrizes) / 2.0 * 100)))

        // Bench Flexibility: 5 bench slots minus distinct engine Pokémon SPECIES (not copies).
        // Running 3× Bibarel still occupies 1 bench slot, not 3.
        // Engine sitters = ability-Pokémon whose role tags include Draw / Search / Energy Acceleration.
        // entries is already merged by name (one entry per unique card name), so the Set
        // deduplicates across any same-named printings that may remain after merging.
        //
        // Evolution lines (e.g. Bidoof → Bibarel, Pidgey → Pidgeot ex) count as 1 slot because
        // engine abilities live on the evolved form only. The pre-evolutions lack Draw/Search/
        // EnergyAcceleration tags and are filtered out, so the line contributes exactly 1 entry
        // to engineBenchNames. No evolvesFrom data is required for this to be correct.
        var engineBenchNames = Set<String>()
        for entry in entries where entry.supertype == "Pokémon" && entry.hasAbility {
            let tags = roleTags(entry.name)
            if tags.contains("Draw") || tags.contains("Search") || tags.contains("Energy Acceleration") {
                engineBenchNames.insert(entry.name)
            }
        }
        let engineSlots           = min(5, engineBenchNames.count)
        let benchFlexibilityScore = max(0, (5 - engineSlots) * 20)

        // Opening Reliability: P(≥1 Basic Pokémon in opening hand of 7).
        // basicOpeningHandProbability is calculated below; capture it as Int here.

        let totalPokemon = singlePrizeCopies + rulePokemonCopies
        let prizeResilienceScore = totalPokemon == 0 ? 50 : singlePrizeCopies * 100 / totalPokemon

        let disruptionScore = min(100, min(disruptionCount, 10) * 10)
        // Gusting: 5 copies = 100 (a full playset of Boss's Orders scores 80)
        let gustingScore = min(100, min(gustingCount, 5) * 20)

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
        let openingReliabilityScore = min(100, Int(basicOpeningHandProbability * 100))

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
            gustingScore: gustingScore,
            evolutionScore: evolutionScore,
            recoveryScore: recoveryScore,
            itemDependencyScore: itemDependencyScore,
            mobilityScore: mobilityScore,
            keyCards: keyCards,
            turnTwoAggressionScore: turnTwoAggressionScore,
            prizeEfficiencyScore: prizeEfficiencyScore,
            benchFlexibilityScore: benchFlexibilityScore,
            openingReliabilityScore: openingReliabilityScore
        )
    }
}
