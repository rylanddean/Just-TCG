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

        let attackerTypes = Set(
            deck.filter { $0.supertype == "Pokémon" }.flatMap { $0.types }
        )
        let userWeaknessTypes = Set(
            deck.filter { $0.supertype == "Pokémon" }.compactMap { $0.weaknessType }
        )
        let abilityCardNames = Set(
            deck.filter { $0.supertype == "Pokémon" && $0.hasAbility }.map { $0.name }
        )

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

            let isUnfavoured = userWeaknessTypes.contains(metaAttackType)

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
            case .unfavoured: advantageScore = 0
            }

            entries.append(MatchupEntry(
                id: UUID(),
                archetypeName: share.archetypeName,
                primaryType: primaryType,
                weaknessType: weaknessType,
                metaSharePercent: share.sharePercent,
                advantage: advantage,
                abilitySource: abilitySource
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
