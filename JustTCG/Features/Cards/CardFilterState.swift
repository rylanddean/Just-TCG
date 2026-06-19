import SwiftData

struct FilterChipItem: Identifiable {
    let id: String
    let label: String
}

enum CardGroup: String, CaseIterable, Identifiable {
    case pokemon   = "Pokémon"
    case supporter = "Supporter"
    case item      = "Item"
    case tool      = "Tool"
    case stadium   = "Stadium"
    case aceSpec   = "ACE SPEC"
    case energy    = "Energy"

    var id: String { rawValue }
}

struct CardFilterState: Equatable {
    var cardGroup: CardGroup? = nil

    // Basic
    var types: Set<String> = []
    var subtypes: Set<String> = []
    var sets: Set<String> = []

    // Set & Legality
    var regulationMarks: Set<String> = []
    var rarities: Set<String> = []

    // Stats
    var hpMin: Int? = nil
    var hpMax: Int? = nil
    var damageMin: Int? = nil
    var damageMax: Int? = nil
    var retreatCosts: Set<Int> = []
    var hasAbility: Bool? = nil

    // Matchup
    var weaknessTypes: Set<String> = []
    var resistanceTypes: Set<String> = []
    var attackingEnergyTypes: Set<String> = []

    // Role
    var roleTags: Set<String> = []

    static let allRoleTags: [String] = [
        "Draw", "Search", "Acceleration", "Healing",
        "Damage Reduction", "Damage Boost", "HP Boost", "Disruption", "Gusting", "Status",
        "Spread", "Spread Protection", "Survivability", "Mobility", "Prize Control", "Lock",
    ]

    // True when any active filter cannot be pushed to the DB predicate and must
    // be evaluated in memory. When false, pure DB pagination is safe.
    var hasComplexFilters: Bool {
        !types.isEmpty || !subtypes.isEmpty || !rarities.isEmpty ||
        !regulationMarks.isEmpty || hpMin != nil || hpMax != nil ||
        damageMin != nil || damageMax != nil || !retreatCosts.isEmpty ||
        hasAbility != nil ||
        !weaknessTypes.isEmpty || !resistanceTypes.isEmpty ||
        !attackingEnergyTypes.isEmpty || !roleTags.isEmpty
    }

    // True when cardGroup is a Trainer sub-category whose distinction requires
    // an in-memory subtype check after the DB-level supertype filter.
    var groupNeedsInMemoryCheck: Bool {
        switch cardGroup {
        case .supporter, .item, .tool, .stadium, .aceSpec: return true
        default: return false
        }
    }

    var isEmpty: Bool {
        cardGroup == nil &&
        types.isEmpty &&
        subtypes.isEmpty &&
        sets.isEmpty &&
        regulationMarks.isEmpty &&
        rarities.isEmpty &&
        hpMin == nil &&
        hpMax == nil &&
        damageMin == nil &&
        damageMax == nil &&
        retreatCosts.isEmpty &&
        hasAbility == nil &&
        weaknessTypes.isEmpty &&
        resistanceTypes.isEmpty &&
        attackingEnergyTypes.isEmpty &&
        roleTags.isEmpty
    }

    // Post-fetch in-memory filter. Applies all active criteria to a single card.
    func passes(_ card: CachedCard) -> Bool {
        if let group = cardGroup {
            switch group {
            case .pokemon:
                if card.types.isEmpty || card.supertype == "Energy" { return false }
            case .supporter:
                if !card.subtypes.contains("Supporter") { return false }
            case .item:
                if !card.subtypes.contains("Item") { return false }
            case .tool:
                if !card.subtypes.contains("Pokémon Tool") { return false }
            case .stadium:
                if !card.subtypes.contains("Stadium") { return false }
            case .aceSpec:
                if !card.subtypes.contains("ACE SPEC") { return false }
            case .energy:
                if card.supertype != "Energy" { return false }
            }
        }
        if !types.isEmpty, Set(card.types).isDisjoint(with: types) { return false }
        if !subtypes.isEmpty, Set(card.subtypes).isDisjoint(with: subtypes) { return false }
        if !sets.isEmpty, !sets.contains(card.setCode) { return false }
        if !regulationMarks.isEmpty {
            guard let mark = card.regulationMark, regulationMarks.contains(mark) else { return false }
        }
        if !rarities.isEmpty {
            guard let rarity = card.rarity, rarities.contains(rarity) else { return false }
        }
        if let min = hpMin, (card.hp ?? 0) < min { return false }
        if let max = hpMax, (card.hp ?? 0) > max { return false }
        if let min = damageMin {
            guard let dmg = card.maxDamage, dmg >= min else { return false }
        }
        if let max = damageMax {
            guard let dmg = card.maxDamage, dmg <= max else { return false }
        }
        if !retreatCosts.isEmpty {
            guard let rc = card.retreatCost, retreatCosts.contains(rc) else { return false }
        }
        if let wantAbility = hasAbility, card.hasAbility != wantAbility { return false }
        if !weaknessTypes.isEmpty {
            guard let wt = card.weaknessType, weaknessTypes.contains(wt) else { return false }
        }
        if !resistanceTypes.isEmpty {
            guard let rt = card.resistanceType, resistanceTypes.contains(rt) else { return false }
        }
        if !attackingEnergyTypes.isEmpty {
            let costs = Set(card.attackEnergyCosts)
            if costs.isDisjoint(with: attackingEnergyTypes) { return false }
        }
        if !roleTags.isEmpty, Set(card.roleTags).isDisjoint(with: roleTags) { return false }
        return true
    }

    // Chip descriptions for the active-filters row. Each chip has an id matching
    // the filter group key so clearChip can remove the whole group at once.
    var activeChips: [FilterChipItem] {
        var chips: [FilterChipItem] = []

        if let group = cardGroup {
            chips.append(FilterChipItem(id: "cardGroup", label: group.rawValue))
        }
        if !types.isEmpty {
            chips.append(FilterChipItem(id: "types", label: types.sorted().joined(separator: ", ")))
        }
        if !subtypes.isEmpty {
            chips.append(FilterChipItem(id: "subtypes", label: subtypes.sorted().joined(separator: ", ")))
        }
        if !sets.isEmpty {
            chips.append(FilterChipItem(id: "sets", label: "Set: \(sets.count)"))
        }
        if !regulationMarks.isEmpty {
            chips.append(FilterChipItem(id: "marks", label: "Mark: \(regulationMarks.sorted().joined(separator: ", "))"))
        }
        if !rarities.isEmpty {
            chips.append(FilterChipItem(id: "rarities", label: "Rarity: \(rarities.count)"))
        }
        if hpMin != nil || hpMax != nil {
            let lo = hpMin.map(String.init) ?? "Any"
            let hi = hpMax.map(String.init) ?? "Any"
            chips.append(FilterChipItem(id: "hp", label: "HP: \(lo)–\(hi)"))
        }
        if damageMin != nil || damageMax != nil {
            let lo = damageMin.map(String.init) ?? "Any"
            let hi = damageMax.map(String.init) ?? "Any"
            chips.append(FilterChipItem(id: "damage", label: "Dmg: \(lo)–\(hi)"))
        }
        if !retreatCosts.isEmpty {
            chips.append(FilterChipItem(id: "retreat", label: "Retreat: \(retreatCosts.sorted().map(String.init).joined(separator: ", "))"))
        }
        if let ab = hasAbility {
            chips.append(FilterChipItem(id: "ability", label: ab ? "Has Ability" : "No Ability"))
        }
        if !weaknessTypes.isEmpty {
            chips.append(FilterChipItem(id: "weakness", label: "Weak: \(weaknessTypes.sorted().joined(separator: ", "))"))
        }
        if !resistanceTypes.isEmpty {
            chips.append(FilterChipItem(id: "resistance", label: "Resist: \(resistanceTypes.sorted().joined(separator: ", "))"))
        }
        if !attackingEnergyTypes.isEmpty {
            chips.append(FilterChipItem(id: "energy", label: "Energy: \(attackingEnergyTypes.sorted().joined(separator: ", "))"))
        }
        if !roleTags.isEmpty {
            let label: String
            if roleTags.count > 2 {
                label = "Role: \(roleTags.count) roles"
            } else {
                label = "Role: \(roleTags.sorted().joined(separator: ", "))"
            }
            chips.append(FilterChipItem(id: "roleTags", label: label))
        }
        return chips
    }

    mutating func clearChip(id: String) {
        switch id {
        case "cardGroup":  cardGroup = nil
        case "types":      types = []
        case "subtypes":   subtypes = []
        case "sets":       sets = []
        case "marks":      regulationMarks = []
        case "rarities":   rarities = []
        case "hp":         hpMin = nil; hpMax = nil
        case "damage":     damageMin = nil; damageMax = nil
        case "retreat":    retreatCosts = []
        case "ability":    hasAbility = nil
        case "weakness":   weaknessTypes = []
        case "resistance": resistanceTypes = []
        case "energy":     attackingEnergyTypes = []
        case "roleTags":   roleTags = []
        default: break
        }
    }
}
