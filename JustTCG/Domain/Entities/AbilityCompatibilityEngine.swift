import Foundation

// MARK: - Supporting types

enum AbilitySeverity {
    case ok
    case caution
    case conflict
}

enum AbilityConditionType: Equatable {
    case unconditional
    case minimumInPlay(count: Int, qualifier: String)
    case namedCardRequired(cardName: String)
    case categoryPokemonRequired(subtypeKeyword: String, typeFilter: String?)
    case activationCost(cardPattern: String, isEnergy: Bool)
    case trainerRequired(cardName: String)
    case selfEnergyRequired(energyType: String)
    case prizeDependent
    case unknown
}

struct AbilityCompatibilityResult {
    let cardName: String
    let copies: Int
    let abilityName: String
    let conditionType: AbilityConditionType
    let score: Int
    let severity: AbilitySeverity
    let warningMessage: String?
}

struct AbilityCompatibilityBreakdown {
    let results: [AbilityCompatibilityResult]
    let compatibilityScore: Int

    var conflicts: [AbilityCompatibilityResult] { results.filter { $0.severity == .conflict } }
    var cautions: [AbilityCompatibilityResult]  { results.filter { $0.severity == .caution } }
    var hasIssues: Bool { results.contains { $0.severity != .ok } }
}

// MARK: - Engine

struct AbilityCompatibilityEngine {

    // MARK: Public API

    func breakdown(
        entries: [DeckCardEntry],
        abilityTexts: (String) -> [(name: String, text: String)],
        roleTags: (String) -> [String] = { _ in [] }
    ) -> AbilityCompatibilityBreakdown {
        var results: [AbilityCompatibilityResult] = []

        let support = setupSupportFactor(entries: entries, roleTags: roleTags)

        for entry in entries where entry.supertype == "Pokémon" && entry.hasAbility {
            let abilities = abilityTexts(entry.name)
            guard !abilities.isEmpty else { continue }

            // Find the worst-scoring ability on this card
            var worstScore = 100
            var worstAbilityName = abilities[0].name
            var worstCondition = AbilityConditionType.unconditional

            for ability in abilities {
                let conditions = detectConditions(in: ability.text)
                let abilityScore = conditions.map { score(for: $0, in: entries, supportFactor: support) }.min() ?? 100
                let primaryCondition = conditions.min(by: {
                    score(for: $0, in: entries, supportFactor: support) < score(for: $1, in: entries, supportFactor: support)
                }) ?? .unconditional

                if abilityScore < worstScore {
                    worstScore = abilityScore
                    worstAbilityName = ability.name
                    worstCondition = primaryCondition
                }
            }

            let severity = Self.severity(for: worstScore)
            let warning = severity == .ok ? nil : warningMessage(
                cardName: entry.name,
                abilityName: worstAbilityName,
                condition: worstCondition,
                score: worstScore,
                entries: entries,
                supportFactor: support
            )

            results.append(AbilityCompatibilityResult(
                cardName: entry.name,
                copies: entry.copies,
                abilityName: worstAbilityName,
                conditionType: worstCondition,
                score: worstScore,
                severity: severity,
                warningMessage: warning
            ))
        }

        results.sort { $0.score < $1.score }

        let conflictCount = results.filter { $0.severity == .conflict }.count
        let cautionCount  = results.filter { $0.severity == .caution }.count
        let deckScore = max(0, 100 - conflictCount * 30 - cautionCount * 15)

        return AbilityCompatibilityBreakdown(results: results, compatibilityScore: deckScore)
    }

    // MARK: Ability text parsing

    static func parseAbilities(from rulesText: [String]) -> [(name: String, text: String)] {
        var result: [(name: String, text: String)] = []
        for line in rulesText {
            guard line.hasPrefix("[Ability]") || line.hasPrefix("[Pokémon Power]") else { continue }
            let parts = line.components(separatedBy: "\n")
            guard let header = parts.first else { continue }
            let name = header
                .replacingOccurrences(of: "[Ability] ", with: "")
                .replacingOccurrences(of: "[Pokémon Power] ", with: "")
                .trimmingCharacters(in: .whitespaces)
            let text = parts.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespaces)
            result.append((name: name, text: text))
        }
        return result
    }

    // MARK: - Condition detection

    func detectConditions(in text: String) -> [AbilityConditionType] {
        let lower = text.lowercased()
        var conditions: [AbilityConditionType] = []

        // Type A — minimum count in play
        if let c = detectMinimumInPlay(lower) { conditions.append(c) }

        // Type B — named card required (check before C to handle "any Pecharunt ex")
        if let c = detectNamedCard(lower) { conditions.append(c) }

        // Type C — category Pokémon required
        if let c = detectCategoryPokemon(lower) { conditions.append(c) }

        // Type D — activation cost
        if let c = detectActivationCost(lower) { conditions.append(c) }

        // Type E — trainer played from hand
        if let c = detectTrainerPlayed(lower) { conditions.append(c) }

        // Type F — self energy type
        if let c = detectSelfEnergy(lower) { conditions.append(c) }

        // Prize-dependent
        if lower.contains("fewer prize") || lower.contains("more prize") || lower.contains("prize cards remaining")
            || lower.contains("same number of cards in your hand as your opponent") {
            conditions.append(.prizeDependent)
        }

        if conditions.isEmpty {
            // Check for unclassified conditional keywords
            let condKeywords = ["unless", "if you have", "as long as you have", "if you don't have"]
            if condKeywords.contains(where: { lower.contains($0) }) {
                conditions.append(.unknown)
            }
        }

        return conditions.isEmpty ? [.unconditional] : conditions
    }

    // MARK: - Individual detectors

    private func detectMinimumInPlay(_ lower: String) -> AbilityConditionType? {
        // Patterns: "N or more X pokémon in play", "unless you have N or more X pokémon in play"
        let patterns = [
            #"(\d+) or more (.+?)pok[eé]mon in play"#,
            #"at least (\d+) (.+?)pok[eé]mon in play"#,
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
                  let countRange = Range(match.range(at: 1), in: lower),
                  let qualRange  = Range(match.range(at: 2), in: lower),
                  let count = Int(lower[countRange])
            else { continue }

            let qualifier = String(lower[qualRange])
                .trimmingCharacters(in: .whitespaces)
                .capitalized
                .trimmingCharacters(in: .whitespaces)
            return .minimumInPlay(count: count, qualifier: qualifier)
        }
        return nil
    }

    private let categoryKeywords = ["tera", "mega", "fire", "water", "grass", "lightning",
                                    "fighting", "psychic", "darkness", "metal", "dragon", "colorless"]

    private func detectNamedCard(_ lower: String) -> AbilityConditionType? {
        // Pattern: "if you have [any] X in play" or "if you have [any] X on your bench"
        // where X is a specific card name (not a category keyword)
        let pattern = #"if you have (?:any )?([a-z][a-z0-9 '♂♀\-]+?) (?:in play|on your bench)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
              let nameRange = Range(match.range(at: 1), in: lower)
        else { return nil }

        let captured = String(lower[nameRange]).trimmingCharacters(in: .whitespaces)

        // If the captured text contains a category keyword followed by "pokémon" or is itself
        // a category keyword, it belongs to Type C
        let words = captured.components(separatedBy: .whitespaces)
        let hasCategoryWord = words.contains(where: { categoryKeywords.contains($0) })
        if hasCategoryWord { return nil }

        // Title-case the card name
        let cardName = captured.split(separator: " ").map { word -> String in
            guard let first = word.first else { return String(word) }
            return first.uppercased() + word.dropFirst()
        }.joined(separator: " ")

        return .namedCardRequired(cardName: cardName)
    }

    private func detectCategoryPokemon(_ lower: String) -> AbilityConditionType? {
        let pattern = #"if you have any (.+?)pok[eé]mon"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
              let prefixRange = Range(match.range(at: 1), in: lower)
        else { return nil }

        let prefix = String(lower[prefixRange]).trimmingCharacters(in: .whitespaces)

        if prefix.contains("tera") {
            return .categoryPokemonRequired(subtypeKeyword: "Tera", typeFilter: nil)
        }

        if prefix.contains("mega") {
            let typeNames = ["fire", "water", "grass", "lightning", "fighting",
                             "psychic", "darkness", "metal", "dragon", "colorless"]
            let typeFilter = typeNames.first(where: { prefix.contains($0) })?.capitalized
            return .categoryPokemonRequired(subtypeKeyword: "MEGA", typeFilter: typeFilter)
        }

        return nil
    }

    private let genericDiscardPatterns = [#"^\d+ cards?$"#, #"^a cards?$"#, #"^cards?$"#]

    private func detectActivationCost(_ lower: String) -> AbilityConditionType? {
        let pattern = #"you must discard (?:a |an )?(.+?)(?: from| in order)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
              let captureRange = Range(match.range(at: 1), in: lower)
        else { return nil }

        var captured = String(lower[captureRange]).trimmingCharacters(in: .whitespaces)

        // Strip trailing " card" or " cards" — these are syntactic in the card text, not part of the name
        if captured.hasSuffix(" cards") { captured = String(captured.dropLast(6)).trimmingCharacters(in: .whitespaces) }
        else if captured.hasSuffix(" card") { captured = String(captured.dropLast(5)).trimmingCharacters(in: .whitespaces) }

        // Skip generic discards ("a", "2", etc. with no named card/energy)
        let isGeneric = genericDiscardPatterns.contains { pattern in
            (try? NSRegularExpression(pattern: pattern))?.firstMatch(in: captured, range: NSRange(captured.startIndex..., in: captured)) != nil
        }
        if isGeneric || captured.isEmpty { return nil }

        let isEnergy = captured.contains("energy")
        // Capitalise the pattern for display
        let display = captured.split(separator: " ").map { w -> String in
            guard let f = w.first else { return String(w) }
            return f.uppercased() + w.dropFirst()
        }.joined(separator: " ")

        return .activationCost(cardPattern: display, isEnergy: isEnergy)
    }

    private func detectTrainerPlayed(_ lower: String) -> AbilityConditionType? {
        let pattern = #"if you played (.+?) from your hand this turn"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
              let nameRange = Range(match.range(at: 1), in: lower)
        else { return nil }

        let raw = String(lower[nameRange]).trimmingCharacters(in: .whitespaces)
        let cardName = raw.split(separator: " ").map { w -> String in
            guard let f = w.first else { return String(w) }
            return f.uppercased() + w.dropFirst()
        }.joined(separator: " ")

        return .trainerRequired(cardName: cardName)
    }

    private let energyTypeNames = ["fire", "water", "grass", "lightning", "fighting",
                                   "psychic", "darkness", "metal", "dragon", "colorless", "special"]

    private func detectSelfEnergy(_ lower: String) -> AbilityConditionType? {
        let pattern = #"if this pok[eé]mon has any (.+?) energy attached"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
              let typeRange = Range(match.range(at: 1), in: lower)
        else { return nil }

        let raw = String(lower[typeRange]).trimmingCharacters(in: .whitespaces)
        guard energyTypeNames.contains(raw) else { return nil }
        return .selfEnergyRequired(energyType: raw.capitalized)
    }

    // MARK: - Setup support factor

    // Scores the deck's ability to SET UP the bench: Trainer search cards get Pokémon
    // out of the deck directly; ability draw engines let you see more cards per turn.
    // Returned value is added to the effective probability in minimumInPlay scoring only.
    private func setupSupportFactor(entries: [DeckCardEntry], roleTags: (String) -> [String]) -> Double {
        // Trainer cards that can search the deck (Items/Supporters with "Search" role tag)
        let searchItemCount = entries.filter { entry in
            entry.supertype == "Trainer" && roleTags(entry.name).contains("Search")
        }.reduce(0) { $0 + $1.copies }

        // Bench-sitting ability Pokémon that draw cards each turn (Draw role tag + hasAbility)
        // Count distinct entries — two unique draw engines matter more than 4 copies of one.
        let drawEngineCount = entries.filter { entry in
            entry.supertype == "Pokémon" && entry.hasAbility && roleTags(entry.name).contains("Draw")
        }.count

        // 4 search items ≈ +0.10; cap at +0.20. Each draw engine ≈ +0.08; cap at +0.15.
        let searchFactor = min(Double(searchItemCount) * 0.025, 0.20)
        let drawFactor   = min(Double(drawEngineCount)  * 0.08,  0.15)
        return searchFactor + drawFactor  // max 0.35
    }

    // MARK: - Scoring

    func score(for condition: AbilityConditionType, in entries: [DeckCardEntry], supportFactor: Double = 0) -> Int {
        switch condition {
        case .unconditional:
            return 100

        case .minimumInPlay(let count, let qualifier):
            let matching = matchingCount(qualifier: qualifier, in: entries)
            guard matching >= count else { return 0 }
            // supportFactor lifts effective probability to account for search items and draw engines
            // that make it easier to find and bench the required Pokémon by turn 4.
            let baseP = ConsistencyEngine.probabilityAtLeast(
                copies: matching, deckSize: 60, drawn: 11, desired: count
            ) * 0.80
            let p = min(1.0, baseP + supportFactor)
            switch p {
            case 0.60...: return 100
            case 0.40..<0.60: return 65
            case 0.20..<0.40: return 35
            default: return 10
            }

        case .namedCardRequired(let cardName):
            let copies = totalCopies(of: cardName, in: entries)
            return namedCardScore(copies: copies)

        case .categoryPokemonRequired(let subtypeKeyword, let typeFilter):
            let n = categoryCount(subtypeKeyword: subtypeKeyword, typeFilter: typeFilter, in: entries)
            switch n {
            case 0: return 5
            case 1: return 65
            default: return 90
            }

        case .activationCost(let pattern, let isEnergy):
            if isEnergy {
                let energyType = extractEnergyType(from: pattern)
                let count = energyCardCount(ofType: energyType, in: entries)
                switch count {
                case 0: return 0
                case 1: return 40
                case 2...3: return 65
                default: return 100
                }
            } else {
                // Named item
                let copies = totalCopies(of: pattern, in: entries)
                switch copies {
                case 0: return 0
                case 1: return 60
                default: return 90
                }
            }

        case .trainerRequired(let cardName):
            let copies = totalCopies(of: cardName, in: entries)
            return namedCardScore(copies: copies)

        case .selfEnergyRequired(let energyType):
            if energyType.lowercased() == "special" {
                let count = entries.filter {
                    $0.supertype == "Energy" && $0.subtypes.contains("Special")
                }.reduce(0) { $0 + $1.copies }
                switch count {
                case 0: return 0
                case 1: return 55
                default: return 80
                }
            } else {
                let count = energyCardCount(ofType: energyType, in: entries)
                switch count {
                case 0: return 0
                case 1: return 50
                case 2...3: return 80
                default: return 100
                }
            }

        case .prizeDependent:
            return 55

        case .unknown:
            return 50
        }
    }

    // MARK: - Qualifier resolution helpers

    private func matchingCount(qualifier: String, in entries: [DeckCardEntry]) -> Int {
        let q = qualifier.trimmingCharacters(in: .whitespaces).lowercased()
        let pokemon = entries.filter { $0.supertype == "Pokémon" }

        if q.isEmpty {
            return pokemon.reduce(0) { $0 + $1.copies }
        }

        let typeNames = ["fire","water","grass","lightning","fighting",
                         "psychic","darkness","metal","dragon","colorless"]
        if typeNames.contains(q) {
            return pokemon
                .filter { $0.types.map { $0.lowercased() }.contains(q) }
                .reduce(0) { $0 + $1.copies }
        }

        // Subtype match
        let allSubtypes = entries.flatMap(\.subtypes).map { $0.lowercased() }
        if allSubtypes.contains(q) {
            return pokemon
                .filter { $0.subtypes.map { $0.lowercased() }.contains(q) }
                .reduce(0) { $0 + $1.copies }
        }

        // Name prefix match (e.g. "Team Rocket's")
        return pokemon
            .filter { $0.name.lowercased().hasPrefix(q) }
            .reduce(0) { $0 + $1.copies }
    }

    private func categoryCount(subtypeKeyword: String, typeFilter: String?, in entries: [DeckCardEntry]) -> Int {
        entries.filter { entry in
            guard entry.supertype == "Pokémon" else { return false }
            let hasSubtype = entry.subtypes.contains(subtypeKeyword)
            let hasType = typeFilter.map { entry.types.contains($0) } ?? true
            return hasSubtype && hasType
        }.reduce(0) { $0 + $1.copies }
    }

    private func totalCopies(of name: String, in entries: [DeckCardEntry]) -> Int {
        entries
            .filter { $0.name.lowercased() == name.lowercased() }
            .reduce(0) { $0 + $1.copies }
    }

    private func energyCardCount(ofType energyType: String, in entries: [DeckCardEntry]) -> Int {
        entries
            .filter { $0.supertype == "Energy" && $0.name.lowercased().contains(energyType.lowercased()) }
            .reduce(0) { $0 + $1.copies }
    }

    private func extractEnergyType(from pattern: String) -> String {
        // "Basic Fire Energy" → "Fire"
        let words = pattern.components(separatedBy: .whitespaces)
        let typeWords = ["Fire","Water","Grass","Lightning","Fighting","Psychic","Darkness","Metal","Dragon","Colorless"]
        return words.first(where: { typeWords.contains($0) }) ?? pattern
    }

    private func namedCardScore(copies: Int) -> Int {
        switch copies {
        case 0: return 0
        case 1: return 40
        case 2: return 65
        case 3: return 85
        default: return 100
        }
    }

    // MARK: - Severity

    static func severity(for score: Int) -> AbilitySeverity {
        switch score {
        case 70...: return .ok
        case 40..<70: return .caution
        default: return .conflict
        }
    }

    // MARK: - Warning message generation

    private func warningMessage(
        cardName: String,
        abilityName: String,
        condition: AbilityConditionType,
        score: Int,
        entries: [DeckCardEntry],
        supportFactor: Double = 0
    ) -> String {
        switch condition {
        case .minimumInPlay(let count, let qualifier):
            let matching = matchingCount(qualifier: qualifier, in: entries)
            let qualDisplay = qualifier.isEmpty ? "Pokémon" : qualifier + " Pokémon"
            if matching < count {
                return "\(abilityName) requires \(count)+ \(qualDisplay) in play, but the deck only has \(matching) — condition can never be met."
            } else {
                let pct = Int(round(Double(score) * 0.6))
                var msg = "\(abilityName) requires \(count)+ \(qualDisplay) in play. The deck has \(matching) — condition is met roughly \(pct)% of the time by turn 4."
                if supportFactor >= 0.10 {
                    msg += " Draw and search support improves bench setup reliability."
                }
                return msg
            }

        case .namedCardRequired(let name):
            let copies = totalCopies(of: name, in: entries)
            if copies == 0 {
                return "\(abilityName) requires \(name) in play, but the deck contains 0 copies."
            }
            return "\(abilityName) requires \(name) in play — deck has \(copies) \(copies == 1 ? "copy" : "copies")."

        case .categoryPokemonRequired(let subtype, let typeFilter):
            let label = typeFilter.map { "\($0) \(subtype)" } ?? subtype
            let n = categoryCount(subtypeKeyword: subtype, typeFilter: typeFilter, in: entries)
            if n == 0 {
                return "\(abilityName) requires a \(label) Pokémon in play, but the deck contains none."
            }
            return "\(abilityName) requires a \(label) Pokémon in play — deck has \(n) \(n == 1 ? "copy" : "copies")."

        case .activationCost(let pattern, let isEnergy):
            if isEnergy {
                let energyType = extractEnergyType(from: pattern)
                let count = energyCardCount(ofType: energyType, in: entries)
                if count == 0 {
                    return "\(abilityName) requires discarding \(pattern) — deck contains 0 \(energyType) Energy cards."
                }
                return "\(abilityName) requires discarding \(pattern) — deck has \(count) \(count == 1 ? "copy" : "copies")."
            } else {
                let copies = totalCopies(of: pattern, in: entries)
                if copies == 0 {
                    return "\(abilityName) requires discarding \(pattern) — deck contains 0 copies."
                }
                return "\(abilityName) requires discarding \(pattern) — deck has \(copies) \(copies == 1 ? "copy" : "copies")."
            }

        case .trainerRequired(let name):
            let copies = totalCopies(of: name, in: entries)
            if copies == 0 {
                return "\(abilityName) only fires when \(name) is played this turn — deck contains 0 copies."
            }
            return "\(abilityName) only fires when \(name) is played this turn — deck has \(copies) \(copies == 1 ? "copy" : "copies")."

        case .selfEnergyRequired(let energyType):
            let count: Int
            if energyType.lowercased() == "special" {
                count = entries.filter { $0.supertype == "Energy" && $0.subtypes.contains("Special") }.reduce(0) { $0 + $1.copies }
            } else {
                count = energyCardCount(ofType: energyType, in: entries)
            }
            if count == 0 {
                return "\(abilityName) requires \(energyType) Energy attached — deck contains 0 \(energyType) Energy cards."
            }
            return "\(abilityName) requires \(energyType) Energy attached — deck has \(count) \(count == 1 ? "copy" : "copies")."

        case .prizeDependent:
            return "\(abilityName) effectiveness depends on prize count — unpredictable from deck composition alone."

        case .unknown:
            return "\(abilityName) has a conditional trigger that couldn't be fully analysed — review manually."

        case .unconditional:
            return nil ?? ""
        }
    }
}
