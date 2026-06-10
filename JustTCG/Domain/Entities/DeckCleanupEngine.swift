import Foundation

// MARK: - Model

enum CleanupAxis: String {
    case evolution      = "Evolution"
    case energySetup    = "Energy Setup"
    case recovery       = "Recovery"
    case mobility       = "Mobility"
    case itemDependency = "Item Dependency"
    case disruption     = "Disruption"

    var systemImage: String {
        switch self {
        case .evolution:      return "arrow.up.forward.circle"
        case .energySetup:    return "bolt.fill"
        case .recovery:       return "arrow.counterclockwise.circle.fill"
        case .mobility:       return "figure.run"
        case .itemDependency: return "cube.box"
        case .disruption:     return "bolt.horizontal.fill"
        }
    }
}

enum CleanupSeverity: Int, Comparable {
    case low    = 0
    case medium = 1
    case high   = 2
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

struct CleanupSuggestion: Identifiable {
    let id: String           // cardName + "_" + axis.rawValue
    let cardName: String
    let quantity: Int
    let reasonShort: String  // ≤ 60 chars, shown in the list row
    let reasonLong: String   // 2–3 sentence explainer shown in the detail sheet
    let alternativeName: String? // card to consider adding in place of a copy; nil if none
    let axis: CleanupAxis
    let severity: CleanupSeverity
    let imageURL: String
}

// MARK: - Engine

struct DeckCleanupEngine {

    private static let ruleBoxSubtypes: Set<String> = ["ex", "V", "VSTAR", "VMAX", "GX", "VUNION"]

    /// Returns cut-candidate suggestions anchored to the deck's profile scores.
    /// The caller is responsible for filtering dismissed names and capping to 5.
    func suggestCuts(
        deck: [DeckCardEntry],
        breakdown: ConsistencyBreakdown,
        roleTags: (String) -> [String]
    ) -> [CleanupSuggestion] {

        var raw: [CleanupSuggestion] = []

        raw += evolutionRule(deck: deck, breakdown: breakdown)
        raw += energySetupRule(deck: deck, breakdown: breakdown)
        raw += recoveryRule(deck: deck, breakdown: breakdown, roleTags: roleTags)
        raw += mobilityRule(deck: deck, breakdown: breakdown, roleTags: roleTags)
        raw += itemDependencyRule(deck: deck, breakdown: breakdown, roleTags: roleTags)
        raw += disruptionRule(deck: deck, breakdown: breakdown, roleTags: roleTags)

        // One suggestion per card — keep the highest-severity rule when multiple fire.
        var best: [String: CleanupSuggestion] = [:]
        for sug in raw {
            if let existing = best[sug.cardName] {
                if sug.severity > existing.severity { best[sug.cardName] = sug }
            } else {
                best[sug.cardName] = sug
            }
        }
        return Array(best.values)
    }

    // MARK: - Rules

    /// Evolution Reliability < 70 → flag top-of-line Pokémon with a thin support layer.
    /// Covers both Stage 2 decks (thin middle layer) and Stage 1 decks (thin Basic count).
    private func evolutionRule(deck: [DeckCardEntry], breakdown: ConsistencyBreakdown) -> [CleanupSuggestion] {
        guard breakdown.evolutionScore < 70 else { return [] }

        let stage2Entries = deck.filter { $0.supertype == "Pokémon" && $0.subtypes.contains("Stage 2") }
        let stage1Entries = deck.filter { $0.supertype == "Pokémon" && $0.subtypes.contains("Stage 1") }

        guard !stage2Entries.isEmpty || !stage1Entries.isEmpty else { return [] }

        let stage1Total = stage1Entries.reduce(0) { $0 + $1.copies }
        let rareCandy   = deck.first(where: { $0.name == "Rare Candy" })?.copies ?? 0
        let severity: CleanupSeverity = breakdown.evolutionScore < 40 ? .high : .medium

        if !stage2Entries.isEmpty {
            // Stage 2 deck: flag Stage 2 Pokémon whose middle layer is thinner than the top line.
            let stage2Total = stage2Entries.reduce(0) { $0 + $1.copies }
            let middleLayer = stage1Total + rareCandy
            guard middleLayer < stage2Total else { return [] }

            let reasonShort = rareCandy == 0
                ? "No Rare Candy + thin Stage 1 line"
                : "Middle layer thinner than top line"

            // Build an alternate suggestion: prefer Rare Candy if it's not yet in the deck,
            // otherwise name a Stage 1 that's already present (first match by name).
            let alternative: String
            if rareCandy == 0 {
                alternative = "Rare Candy"
            } else {
                alternative = stage1Entries.first.map { $0.name } ?? "Rare Candy"
            }

            return stage2Entries.map { entry in
                let reasonLong = "Stage 2 decks need a complete ladder: at minimum one Stage 1 (or Rare Candy) for every Stage 2 copy. Your middle layer has \(middleLayer) card\(middleLayer == 1 ? "" : "s") supporting \(stage2Total) copies of \(entry.name) — that's not enough to set up consistently. Consider cutting a copy and adding \(rareCandy == 0 ? "Rare Candy to skip the Stage 1 requirement" : "another copy of the Stage 1")."

                return CleanupSuggestion(
                    id: "\(entry.name)_\(CleanupAxis.evolution.rawValue)",
                    cardName: entry.name,
                    quantity: entry.copies,
                    reasonShort: reasonShort,
                    reasonLong: reasonLong,
                    alternativeName: alternative,
                    axis: .evolution,
                    severity: severity,
                    imageURL: entry.imageURL ?? ""
                )
            }
        } else {
            // Stage 1 deck (no Stage 2): flag Stage 1 Pokémon when Basic count is below 1.5×.
            // Only count non-rule-box Basics as feeders (rule-box Basics don't evolve).
            let basicEntries = deck.filter {
                $0.supertype == "Pokémon" &&
                $0.subtypes.contains("Basic") &&
                Set($0.subtypes).isDisjoint(with: Self.ruleBoxSubtypes)
            }
            let basicFeederTotal = basicEntries.reduce(0) { $0 + $1.copies }

            guard Double(basicFeederTotal) < Double(stage1Total) * 1.5 else { return [] }

            // Name the most-copied feeder Basic as the suggested addition.
            let feederName = basicEntries.max(by: { $0.copies < $1.copies })?.name

            return stage1Entries.map { entry in
                let needed = Int((Double(stage1Total) * 1.5).rounded(.up))
                let reasonLong = "Stage 1 decks need roughly 1.5× as many Basics as Stage 1 copies to evolve reliably — you're running \(stage1Total) Stage 1s but only \(basicFeederTotal) non-rule-box Basics. Without a Basic in the opening hand, \(entry.name) can't play at all. Consider cutting a copy here and adding more of the Basic to hit the \(needed)-Basic target."

                return CleanupSuggestion(
                    id: "\(entry.name)_\(CleanupAxis.evolution.rawValue)",
                    cardName: entry.name,
                    quantity: entry.copies,
                    reasonShort: "Thin Basic support for this Stage 1 line",
                    reasonLong: reasonLong,
                    alternativeName: feederName,
                    axis: .evolution,
                    severity: severity,
                    imageURL: entry.imageURL ?? ""
                )
            }
        }
    }

    /// Energy Setup < 50 → flag attackers whose type has no matching energy in the deck.
    private func energySetupRule(deck: [DeckCardEntry], breakdown: ConsistencyBreakdown) -> [CleanupSuggestion] {
        guard breakdown.energyScore < 50 else { return [] }

        let energyTypes = Set(
            deck.filter { $0.supertype == "Energy" }
               .flatMap { $0.types }
               .filter { $0 != "Colorless" }
        )
        guard !energyTypes.isEmpty else { return [] }

        let severity: CleanupSeverity = breakdown.energyScore < 30 ? .high : .medium

        return deck.compactMap { entry -> CleanupSuggestion? in
            guard entry.supertype == "Pokémon",
                  (entry.minAttackCost ?? 0) > 0,
                  !entry.types.isEmpty else { return nil }

            let attackTypes = Set(entry.types).subtracting(["Colorless"])
            guard !attackTypes.isEmpty, attackTypes.isDisjoint(with: energyTypes) else { return nil }

            let missingType = attackTypes.first ?? "the right"
            let reasonLong = "\(entry.name) needs \(missingType) Energy to attack, but your deck runs none. Without matching energy it can never deal damage — it's a bench slot and Prize liability with no upside. Either remove it from the deck or add a \(missingType) Energy package to support it."

            return CleanupSuggestion(
                id: "\(entry.name)_\(CleanupAxis.energySetup.rawValue)",
                cardName: entry.name,
                quantity: entry.copies,
                reasonShort: "Attack type not covered by energy package",
                reasonLong: reasonLong,
                alternativeName: "\(missingType) Energy",
                axis: .energySetup,
                severity: severity,
                imageURL: entry.imageURL ?? ""
            )
        }
    }

    /// Recovery < 36 (fewer than 3 dedicated recovery cards) → flag single-prize attackers at 3+ copies.
    /// Fires even when some recovery exists — 1-2 copies is not enough for a deep attacker bench.
    ///
    /// "Dedicated recovery" excludes cards whose primary purpose is energy attachment from the
    /// discard pile (e.g. Wondrous Patch), which carry both "Recovery" and "Energy Acceleration"
    /// tags. Those cards shouldn't mask a real gap in Pokémon retrieval.
    private func recoveryRule(
        deck: [DeckCardEntry],
        breakdown: ConsistencyBreakdown,
        roleTags: (String) -> [String]
    ) -> [CleanupSuggestion] {
        // Count only cards whose primary purpose is retrieval, not energy-attachment-from-discard.
        // Cards with both "Recovery" + "Energy Acceleration" (e.g. Wondrous Patch) are excluded.
        let recoveryCount = deck.filter { entry in
            let tags = roleTags(entry.name)
            return tags.contains("Recovery") && !tags.contains("Energy Acceleration")
        }.reduce(0) { $0 + $1.copies }

        // recoveryScore proxy: min(recoveryCount, 8) * 12 — fire when fewer than 3 dedicated cards.
        guard min(100, recoveryCount * 12) < 36 else { return [] }

        let reasonShort = recoveryCount == 0
            ? "No recovery — trim to 2 and add Night Stretcher?"
            : "Thin recovery (\(recoveryCount) card\(recoveryCount == 1 ? "" : "s")) — trim to 2?"
        let severity: CleanupSeverity = recoveryCount == 0 ? .high : .medium
        // Suggest Night Stretcher when 0 recovery; Super Rod as a second when 1 already exists.
        let alternative = recoveryCount == 0 ? "Night Stretcher" : "Night Stretcher"

        return deck.compactMap { entry -> CleanupSuggestion? in
            guard entry.supertype == "Pokémon",
                  entry.copies >= 3,
                  Set(entry.subtypes).isDisjoint(with: Self.ruleBoxSubtypes),
                  (entry.minAttackCost ?? 0) > 0 else { return nil }

            let reasonLong: String
            if recoveryCount == 0 {
                reasonLong = "With no dedicated recovery, once \(entry.name) is knocked out it stays in the discard for the rest of the game. Running ×\(entry.copies) deepens that risk — a bad early trade could leave you without attackers when it matters most. Night Stretcher retrieves any Pokémon or Basic Energy in a single Item play and costs no extra energy."
            } else {
                reasonLong = "Only \(recoveryCount) dedicated recovery card\(recoveryCount == 1 ? "" : "s") means a few knockouts can strand your key pieces in the discard permanently. At ×\(entry.copies) copies this line is deep enough to survive trimming to 2 — use the freed slot for another Night Stretcher so your attacker bench can rebuild after a bad Prize trade."
            }

            return CleanupSuggestion(
                id: "\(entry.name)_\(CleanupAxis.recovery.rawValue)",
                cardName: entry.name,
                quantity: entry.copies,
                reasonShort: reasonShort,
                reasonLong: reasonLong,
                alternativeName: alternative,
                axis: .recovery,
                severity: severity,
                imageURL: entry.imageURL ?? ""
            )
        }
    }

    /// Mobility < 50 → flag high-retreat (≥3) Pokémon when switching support is absent or thin.
    /// Fires even with 1 switching card — one Switch Card rarely covers a heavy retreat bench.
    private func mobilityRule(
        deck: [DeckCardEntry],
        breakdown: ConsistencyBreakdown,
        roleTags: (String) -> [String]
    ) -> [CleanupSuggestion] {
        guard breakdown.mobilityScore < 50 else { return [] }

        // Count only dedicated switching cards — exclude cards that also carry "Recovery"
        // (e.g. Sacred Ash matches "shuffle…into your deck" but it's not a switching card).
        let switchCount = deck.filter { entry in
            let tags = roleTags(entry.name)
            return tags.contains("Mobility") && !tags.contains("Recovery")
        }.reduce(0) { $0 + $1.copies }
        // If the deck has 2+ switching cards the mobility axis is adequately covered.
        guard switchCount < 2 else { return [] }

        let reasonShort = switchCount == 0
            ? "Retreat ≥3, no switching support"
            : "Retreat ≥3, limited switching (only \(switchCount))"
        // Escape Rope is better when you already have 1 Switch — it also forces the opponent to swap.
        let alternative = switchCount == 0 ? "Switch" : "Escape Rope"

        return deck.compactMap { entry -> CleanupSuggestion? in
            guard entry.supertype == "Pokémon",
                  (entry.retreatCost ?? 0) >= 3,
                  entry.copies >= 2 else { return nil }

            let reasonLong: String
            if switchCount == 0 {
                reasonLong = "\(entry.name) has a retreat cost of \(entry.retreatCost ?? 3), and the deck has no switching cards to move it out of the Active Spot for free. Getting stuck Active wastes an entire turn and can snowball quickly. Switch solves this in one card; Escape Rope adds disruption by forcing your opponent to swap their Active too."
            } else {
                reasonLong = "\(entry.name)'s retreat cost of \(entry.retreatCost ?? 3) makes it a liability when it ends up Active unexpectedly. With only \(switchCount) switching card\(switchCount == 1 ? "" : "s") in the deck, a single discard or Prize loss leaves you without an out. Escape Rope is worth adding as a second option — it also pressures your opponent's setup."
            }

            return CleanupSuggestion(
                id: "\(entry.name)_\(CleanupAxis.mobility.rawValue)",
                cardName: entry.name,
                quantity: entry.copies,
                reasonShort: reasonShort,
                reasonLong: reasonLong,
                alternativeName: alternative,
                axis: .mobility,
                severity: .medium,
                imageURL: entry.imageURL ?? ""
            )
        }
    }

    /// Item Dependency > 90 → flag the lowest-utility Item as a Supporter swap candidate.
    private func itemDependencyRule(
        deck: [DeckCardEntry],
        breakdown: ConsistencyBreakdown,
        roleTags: (String) -> [String]
    ) -> [CleanupSuggestion] {
        guard breakdown.itemDependencyScore > 90 else { return [] }

        let items = deck.filter { $0.supertype == "Trainer" && $0.subtypes.contains("Item") }
        guard let worst = items
            .filter({ roleTags($0.name).isEmpty })
            .sorted(by: { $0.copies > $1.copies })
            .first else { return [] }

        let itemPct = breakdown.itemDependencyScore
        let reasonLong = "Your Trainer engine is \(itemPct)% Items — high enough that a single Item-lock effect (Froslass ex, Iron Thorns ex) could shut down almost your entire engine. \(worst.name) is the lowest-utility Item in the deck with no recognised role tags. Swapping it for Iono adds draw power and hand disruption that works regardless of any lock effect."

        return [CleanupSuggestion(
            id: "\(worst.name)_\(CleanupAxis.itemDependency.rawValue)",
            cardName: worst.name,
            quantity: worst.copies,
            reasonShort: "Low-utility Item — consider a Supporter swap",
            reasonLong: reasonLong,
            alternativeName: "Iono",
            axis: .itemDependency,
            severity: .low,
            imageURL: worst.imageURL ?? ""
        )]
    }

    /// Disruption < 30 and Recovery > 70 → flag a duplicated recovery Trainer as a disruption swap.
    private func disruptionRule(
        deck: [DeckCardEntry],
        breakdown: ConsistencyBreakdown,
        roleTags: (String) -> [String]
    ) -> [CleanupSuggestion] {
        guard breakdown.disruptionScore < 30, breakdown.recoveryScore > 70 else { return [] }

        guard let dup = deck
            .filter({ $0.supertype == "Trainer" && roleTags($0.name).contains("Recovery") && $0.copies >= 2 })
            .sorted(by: { $0.copies > $1.copies })
            .first else { return [] }

        let reasonLong = "Your disruption score is low (\(breakdown.disruptionScore)/100) while recovery is strong (\(breakdown.recoveryScore)/100). Without hand disruption or gust pressure, opponents can set up freely while you rebuild. \(dup.name) has \(dup.copies) copies — the deck can manage with one fewer, and the freed slot gives your opponent something to worry about every turn."

        return [CleanupSuggestion(
            id: "\(dup.name)_\(CleanupAxis.disruption.rawValue)",
            cardName: dup.name,
            quantity: dup.copies,
            reasonShort: "Redundant recovery — swap one for Iono/Boss?",
            reasonLong: reasonLong,
            alternativeName: "Iono",
            axis: .disruption,
            severity: .low,
            imageURL: dup.imageURL ?? ""
        )]
    }
}
