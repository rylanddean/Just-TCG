import Foundation

/// A single card recommendation with reason and the score dimension it addresses.
struct CardRecommendation: Identifiable {
    let id: String               // card.id — unique per printing
    let card: CachedCard
    let reason: String
    let scoreLabel: String
    let scoreSystemImage: String
}

/// Analyses a deck's `ConsistencyBreakdown` and returns a ranked list of
/// standard-legal cards from the available pool that would improve the
/// weakest scoring dimensions.
///
/// Ranking signal (higher = better candidate):
///   1. Tag impact   — how many of the deficiency's role tags the card covers
///   2. Meta weight  — curated competitive staple score (0–5)
///   3. Type affinity — Pokémon that share a type with the deck score +3
///   4. New-card bonus — +1 for cards not already in the deck
struct DeckRecommendationEngine {

    // MARK: - Deficiency model

    private struct Deficiency {
        let scoreLabel: String
        let scoreSystemImage: String
        let score: Int
        /// Cards must carry at least one of these tags to qualify.
        let requiredTags: [String]
        /// Per-tag rank weight used when computing tag impact.
        let tagWeights: [String: Int]
        let reason: String
        let requiresAbility: Bool
        let supertypeFilter: String?
    }

    // MARK: - Meta popularity weights
    //
    // Curated list of universally-played Standard competitive staples.
    // Scale: 5 = appears in almost every top deck
    //        4 = strong staple, widely played
    //        3 = commonly played, deck-dependent
    // Cards absent from this dict receive 0 and rank on tag impact alone.

    private static let metaPopularity: [String: Int] = [
        // ── Draw / Supporters ──────────────────────────────────────────────
        "Professor's Research": 5,
        "Iono": 5,
        "Arven": 4,
        "Judge": 3,
        "Colress's Experiment": 3,
        "Ciphermaniac's Codebreaking": 3,
        "Lacey": 3,

        // ── Pokémon Search / Items ─────────────────────────────────────────
        "Ultra Ball": 5,
        "Nest Ball": 5,
        "Buddy-Buddy Poffin": 4,
        "Earthen Vessel": 4,

        // ── Disruption (hand / board pressure — not gust) ─────────────────
        "Eri": 4,

        // ── Gusting (forces opponent's Active to change) ───────────────────
        "Boss's Orders": 5,
        "Prime Catcher": 4,
        "Counter Catcher": 3,
        "Arven's Toedscruel": 2,
        "Pokémon Catcher": 2,

        // ── Recovery ───────────────────────────────────────────────────────
        "Night Stretcher": 5,
        "Pal Pad": 4,
        "Super Rod": 3,
        "Rescue Board": 3,

        // ── Mobility / Switching ───────────────────────────────────────────
        "Switch Cart": 4,
        "Switch": 3,
        "Escape Rope": 3,

        // ── Energy Acceleration (Supporters / Items) ───────────────────────
        "Crispin": 4,          // Fire
        "Elesa's Sparkle": 3,  // Special Energy

        // ── Ability Engines (Pokémon) ──────────────────────────────────────
        "Bibarel": 5,          // Industrious Incisors — continuous draw
        "Pidgeot ex": 5,       // Quick Search — search any card
        "Lumineon V": 4,       // Lumineon Dive — search Supporter
        "Squawkabilly ex": 4,  // Squawking Party — bench setup
        "Jirachi": 4,          // Stellar Wish — search Basic
        "Farigiraf": 3,        // Long Neck — draw ability
        "Radiant Greninja": 3, // Concealed Cards — draw + discard
    ]

    // MARK: - Public API

    func recommend(
        breakdown: ConsistencyBreakdown,
        deckEntries: [DeckCardEntry],
        allCards: [CachedCard],
        dismissedNames: Set<String>,
        count: Int = 20,
        /// When non-nil, only the matching deficiency is returned (no score gate,
        /// all available candidates up to `count`). Pass nil for auto mode.
        focusedScoreLabel: String? = nil
    ) -> [CardRecommendation] {

        // Derive the deck's primary energy type set for type-affinity scoring
        let deckTypes = Self.deckEnergyTypes(from: deckEntries)

        // Copy counts by card name already in the deck
        let deckCopiesByName: [String: Int] = deckEntries.reduce(into: [:]) { d, e in
            d[e.name] = (d[e.name] ?? 0) + e.copies
        }

        let deficiencies: [Deficiency] = [
            Deficiency(
                scoreLabel: "Consistency",
                scoreSystemImage: "hand.draw",
                score: breakdown.consistencyScore,
                requiredTags: ["Draw", "Search"],
                tagWeights: ["Draw": 4, "Search": 4],
                reason: "Boosts draw and search engine",
                requiresAbility: false,
                supertypeFilter: nil
            ),
            Deficiency(
                scoreLabel: "Ability Impact",
                scoreSystemImage: "pawprint.fill",
                score: breakdown.abilityImpactScore,
                requiredTags: ["Draw", "Search", "Energy Acceleration", "Lock", "Prize Control"],
                tagWeights: ["Draw": 4, "Search": 4, "Energy Acceleration": 3,
                              "Prize Control": 3, "Lock": 3],
                reason: "High-impact ability for your bench",
                requiresAbility: true,
                supertypeFilter: "Pokémon"
            ),
            Deficiency(
                scoreLabel: "Energy Setup",
                scoreSystemImage: "bolt.fill",
                score: breakdown.energyScore,
                requiredTags: ["Energy Acceleration"],
                tagWeights: ["Energy Acceleration": 3],
                reason: "Accelerates energy attachment",
                requiresAbility: false,
                supertypeFilter: nil
            ),
            Deficiency(
                scoreLabel: "Recovery",
                scoreSystemImage: "arrow.counterclockwise.circle.fill",
                score: breakdown.recoveryScore,
                requiredTags: ["Recovery"],
                tagWeights: ["Recovery": 2],
                reason: "Recovers key cards from discard",
                requiresAbility: false,
                supertypeFilter: nil
            ),
            Deficiency(
                scoreLabel: "Mobility",
                scoreSystemImage: "figure.run",
                score: breakdown.mobilityScore,
                requiredTags: ["Mobility"],
                tagWeights: ["Mobility": 1],
                reason: "Adds switching flexibility",
                requiresAbility: false,
                supertypeFilter: nil
            ),
            Deficiency(
                scoreLabel: "Disruption",
                scoreSystemImage: "bolt.horizontal.fill",
                score: breakdown.disruptionScore,
                requiredTags: ["Disruption"],
                tagWeights: ["Disruption": 2],
                reason: "Disrupts your opponent's hand or board",
                requiresAbility: false,
                supertypeFilter: nil
            ),
            Deficiency(
                scoreLabel: "Gusting",
                scoreSystemImage: "arrow.up.to.line.circle.fill",
                score: breakdown.gustingScore,
                requiredTags: ["Gusting"],
                tagWeights: ["Gusting": 3],
                reason: "Forces your opponent's Active Pokémon to change",
                requiresAbility: false,
                supertypeFilter: nil
            ),
        ]
        .sorted { $0.score < $1.score }   // worst dimension first

        var usedNames = Set<String>()      // prevent same card name across deficiencies
        var results: [CardRecommendation] = []

        for deficiency in deficiencies {
            guard results.count < count else { break }

            if let focus = focusedScoreLabel {
                // Focused mode: only process the selected deficiency; no score gate
                guard deficiency.scoreLabel == focus else { continue }
            } else {
                // Auto mode: skip dimensions that are already strong
                guard deficiency.score < 80 else { continue }
            }

            // Focused mode gets the full remaining budget; auto mode caps at 2 per deficiency
            let maxPerDeficiency = focusedScoreLabel != nil ? (count - results.count) : 2

            let candidates = allCards
                .filter { card in
                    guard card.isStandardLegal else { return false }
                    guard !dismissedNames.contains(card.name) else { return false }
                    guard !usedNames.contains(card.name) else { return false }
                    guard (deckCopiesByName[card.name] ?? 0) < 4 else { return false }
                    if let st = deficiency.supertypeFilter, card.supertype != st { return false }
                    if deficiency.requiresAbility, !card.hasAbility { return false }
                    return deficiency.requiredTags.contains { card.roleTags.contains($0) }
                }
                .sorted { lhs, rhs in
                    let ls = Self.candidateScore(lhs, deficiency: deficiency, deckTypes: deckTypes,
                                                 alreadyInDeck: deckCopiesByName[lhs.name] != nil)
                    let rs = Self.candidateScore(rhs, deficiency: deficiency, deckTypes: deckTypes,
                                                 alreadyInDeck: deckCopiesByName[rhs.name] != nil)
                    if ls != rs { return ls > rs }
                    return lhs.name < rhs.name   // stable alphabetical tie-break
                }

            var addedForDeficiency = 0
            for card in candidates {
                guard results.count < count, addedForDeficiency < maxPerDeficiency else { break }
                guard !usedNames.contains(card.name) else { continue }
                usedNames.insert(card.name)
                results.append(CardRecommendation(
                    id: card.id,
                    card: card,
                    reason: deficiency.reason,
                    scoreLabel: deficiency.scoreLabel,
                    scoreSystemImage: deficiency.scoreSystemImage
                ))
                addedForDeficiency += 1
            }
        }

        return results
    }

    // MARK: - Scoring helpers

    /// Combined ranking score for a candidate within one deficiency.
    ///
    /// - Tag impact (0–8): weighted sum of the deficiency tags the card carries
    /// - Meta popularity (0–5): curated competitive staple weight
    /// - Type affinity (0–3): +3 when a Pokémon shares a type with the deck
    /// - New-card bonus (0–1): +1 for cards not already in the deck
    private static func candidateScore(
        _ card: CachedCard,
        deficiency: Deficiency,
        deckTypes: Set<String>,
        alreadyInDeck: Bool
    ) -> Int {
        var score = 0

        // 1. Tag impact
        score += deficiency.tagWeights.reduce(0) {
            $0 + (card.roleTags.contains($1.key) ? $1.value : 0)
        }

        // 2. Meta popularity bonus
        score += metaPopularity[card.name] ?? 0

        // 3. Type affinity — Pokémon only (trainer cards are type-agnostic in the API)
        if card.supertype == "Pokémon", !deckTypes.isEmpty {
            let cardTypes = Set(card.types)
            if !cardTypes.isDisjoint(with: deckTypes) {
                score += 3
            }
        }

        // 4. Prefer cards not already present — new coverage is more valuable
        if !alreadyInDeck { score += 1 }

        return score
    }

    /// Infers the deck's primary energy type(s) from the types of its Pokémon
    /// and Energy cards, ignoring Colorless.
    ///
    /// Only types represented on 2+ copies are returned so that a single
    /// tech Pokémon of a different colour doesn't pollute the profile.
    private static func deckEnergyTypes(from entries: [DeckCardEntry]) -> Set<String> {
        var typeCounts: [String: Int] = [:]
        for entry in entries {
            guard entry.supertype == "Pokémon" || entry.supertype == "Energy" else { continue }
            for type_ in entry.types {
                guard type_ != "Colorless" else { continue }
                typeCounts[type_, default: 0] += entry.copies
            }
        }
        return Set(typeCounts.filter { $0.value >= 2 }.keys)
    }
}
