import Foundation

// MARK: - Models

enum MatchupAdvantage {
    case favoured
    case even
    case unfavoured
}

struct MatchupEntry: Identifiable {
    let id: UUID
    let archetypeName: String
    let primaryType: String
    let weaknessType: String
    let metaSharePercent: Double
    let advantage: MatchupAdvantage
    /// Non-nil when an ability override (not the standard weakness chart) drove a Favoured result.
    let abilitySource: String?
    /// Brief explanation of why this matchup is favoured, even, or unfavoured.
    let reason: String
}

struct MetaMatchupBreakdown {
    let matchupScore: Int
    let matchups: [MatchupEntry]
    /// Primary types of meta archetypes the user's deck is Favoured against (e.g. "Grass", "Fire").
    let favouredAgainstTypes: [String]
    /// Primary types of meta archetypes the user's deck is Unfavoured against (e.g. "Lightning").
    let unfavouredAgainstTypes: [String]
}

// MARK: - Engine

struct MetaMatchupEngine {

    // MARK: - Standard weakness chart (current PTCG Standard format)
    // Used as a fallback when the card's actual weaknessType isn't available in the DB.

    static let weaknessChart: [String: String] = [
        "Fire":       "Water",
        "Water":      "Lightning",
        "Grass":      "Fire",
        "Lightning":  "Fighting",
        "Psychic":    "Darkness",
        "Fighting":   "Psychic",
        "Darkness":   "Fighting",
        "Metal":      "Fire",
        "Dragon":     "Dragon",
        "Colorless":  "Fighting"
    ]

    // MARK: - Ability-based type boost registry

    private struct TypeBoostAbility {
        let cardName: String
        let abilityName: String
        /// Pokémon weak to this type are also treated as weak to `grantsAdvantageToType`.
        let extendsWeaknessFor: String
        let grantsAdvantageToType: String
    }

    private static let typeBoostAbilities: [TypeBoostAbility] = [
        TypeBoostAbility(
            cardName: "Lillie's Clefairy ex",
            abilityName: "Fairy Zone",
            extendsWeaknessFor: "Darkness",
            grantsAdvantageToType: "Colorless"
        )
    ]

    // MARK: - Public API

    /// - Parameters:
    ///   - cardByName: Optional lookup of a CachedCard by exact name. Used to retrieve the
    ///     actual weaknessType printed on the meta archetype's main card — more accurate than
    ///     the hardcoded weakness chart. Pass nil in tests or when the DB isn't available.
    func breakdown(
        deck: [DeckCardEntry],
        metaShares: [ArchetypeShare],
        cardByName: (String) -> CachedCard? = { _ in nil }
    ) -> MetaMatchupBreakdown {

        let pokemonEntries = deck.filter { $0.supertype == "Pokémon" }
        let attackerTypes = Set(pokemonEntries.flatMap { $0.types })
        let abilityCardNames = Set(pokemonEntries.filter { $0.hasAbility }.map { $0.name })

        let topShares = metaShares
            .filter { $0.sharePercent >= 0.5 }
            .sorted { $0.sharePercent > $1.sharePercent }
            .prefix(10)

        var entries: [MatchupEntry] = []
        var totalShare = 0.0
        var weightedScore = 0.0
        var favouredTypes: Set<String> = []
        var unfavouredTypes: Set<String> = []

        for share in topShares {
            guard let archetype = resolvedArchetype(for: share.archetypeName) else { continue }
            let primaryType = archetype.primaryType

            // Prefer actual card weakness data over the hardcoded chart.
            let metaCard = cardByName(archetype.name)
            let weaknessType: String
            if let cardWeakness = metaCard?.weaknessType, !cardWeakness.isEmpty {
                weaknessType = cardWeakness
            } else if let chartWeakness = Self.weaknessChart[primaryType] {
                weaknessType = chartWeakness
            } else {
                continue
            }

            // The type the meta deck attacks with — use card types if available.
            let metaAttackType = metaCard?.types.first ?? primaryType

            // Check favourability
            var isFavoured = attackerTypes.contains(weaknessType)
            var abilitySource: String? = nil

            if !isFavoured {
                for boost in Self.typeBoostAbilities where abilityCardNames.contains(boost.cardName) {
                    if boost.extendsWeaknessFor == weaknessType,
                       attackerTypes.contains(boost.grantsAdvantageToType) {
                        isFavoured = true
                        abilitySource = "\(boost.cardName) — \(boost.abilityName)"
                        break
                    }
                }
            }

            // Exposure: weighted fraction of the user's Pokémon that are weak to metaAttackType.
            // Attackers (role or heuristic) count more because they're the primary prize targets.
            let exposure = weaknessExposure(in: pokemonEntries, to: metaAttackType)
            let isUnfavoured = exposure >= 0.20

            let advantage: MatchupAdvantage
            if isFavoured && !isUnfavoured {
                advantage = .favoured
            } else if isUnfavoured && !isFavoured {
                advantage = .unfavoured
            } else {
                advantage = .even
            }

            if advantage == .favoured   { favouredTypes.insert(primaryType) }
            if advantage == .unfavoured { unfavouredTypes.insert(primaryType) }

            let advantageScore: Double
            switch advantage {
            case .favoured:   advantageScore = 100
            case .even:       advantageScore = 50
            // Scale down from 50 as exposure grows — a 20%-exposed deck scores ~40; 100% exposed scores 0.
            case .unfavoured: advantageScore = 50.0 * (1.0 - exposure)
            }

            let reason: String
            switch advantage {
            case .favoured:
                reason = abilitySource != nil
                    ? "Ability grants type advantage"
                    : "Your deck hits their \(weaknessType) weakness"
            case .unfavoured:
                let hasAttackerWeak = pokemonEntries.contains {
                    $0.pokemonRole == .attacker && $0.weaknessType == metaAttackType
                }
                let hasTechWeak = pokemonEntries.contains {
                    $0.pokemonRole == .tech && $0.weaknessType == metaAttackType
                }
                if hasAttackerWeak {
                    reason = "Your attacker is weak to \(metaAttackType)"
                } else if hasTechWeak {
                    reason = "Your tech cards are weak to \(metaAttackType)"
                } else if exposure >= 0.5 {
                    reason = "Most of your Pokémon are weak to \(metaAttackType)"
                } else {
                    reason = "Some of your Pokémon are weak to \(metaAttackType)"
                }
            case .even:
                if exposure > 0 {
                    reason = "Low \(metaAttackType) exposure — not a meaningful threat"
                } else if isFavoured {
                    reason = "Mutual weakness — advantage cancels out"
                } else {
                    reason = "No type interaction"
                }
            }

            entries.append(MatchupEntry(
                id: UUID(),
                archetypeName: share.archetypeName,
                primaryType: primaryType,
                weaknessType: weaknessType,
                metaSharePercent: share.sharePercent,
                advantage: advantage,
                abilitySource: abilitySource,
                reason: reason
            ))
            totalShare += share.sharePercent
            weightedScore += advantageScore * share.sharePercent
        }

        guard totalShare > 0 else {
            return MetaMatchupBreakdown(
                matchupScore: 50, matchups: [],
                favouredAgainstTypes: [], unfavouredAgainstTypes: []
            )
        }

        let score = Int((weightedScore / totalShare).rounded())
        return MetaMatchupBreakdown(
            matchupScore: score,
            matchups: entries,
            favouredAgainstTypes: favouredTypes.sorted(),
            unfavouredAgainstTypes: unfavouredTypes.sorted()
        )
    }

    // MARK: - Weakness exposure

    /// Returns a 0–1 score for how much of the user's deck is meaningfully exposed to `attackType`.
    /// Role weights: attacker 3×, tech 2×, unlabeled 1×.
    /// A score ≥ 0.20 is treated as a real weakness; below that the meta deck's attack type
    /// affects too little of the deck to matter.
    private func weaknessExposure(in pokemonEntries: [DeckCardEntry], to attackType: String) -> Double {
        var totalWeight = 0.0
        var weakWeight  = 0.0

        for entry in pokemonEntries {
            let roleWeight: Double
            switch entry.pokemonRole {
            case .attacker: roleWeight = 3.0
            case .tech:     roleWeight = 2.0
            case nil:       roleWeight = 1.0
            }
            let w = Double(entry.copies) * roleWeight
            totalWeight += w
            if entry.weaknessType == attackType { weakWeight += w }
        }

        guard totalWeight > 0 else { return 0 }
        return weakWeight / totalWeight
    }

    // MARK: - Archetype resolution

    private func resolvedArchetype(for archetypeName: String) -> Archetype? {
        let key = archetypeName.lowercased()
        let repo = ArchetypeRepository.shared
        // 1. Exact case-insensitive match
        if let match = repo.metaOrdered.first(where: { $0.name.lowercased() == key }) {
            return match
        }
        // 2. Tournament name contains the archetype name (e.g. "Dragapult ex / Pidgeot ex")
        if let match = repo.metaOrdered.first(where: { key.contains($0.name.lowercased()) }) {
            return match
        }
        // 3. Archetype name contains a word from the tournament name (partial fallback)
        let words = key.split(separator: " ").map(String.init).filter { $0.count > 3 }
        return repo.metaOrdered.first { archetype in
            let aKey = archetype.name.lowercased()
            return words.contains { aKey.contains($0) }
        }
    }
}
