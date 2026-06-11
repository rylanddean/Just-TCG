import Foundation
import SwiftData

// Seeds the SwiftData card cache from bundled JSON files on first launch.
// Subsequent launches skip this entirely (UserDefaults check is instant).
// When new regulation sets ship in an app update, bump seededKey's version suffix.
enum BundledCardSeeder {

    static let seededKey = "bundled_cards_seeded_v13"

    private static let setFiles = [
        "TEF", "TWM", "SFA", "SCR", "SSP",
        "PRE", "JTG", "DRI", "BLK", "WHT",
        "MEG", "PFL", "ASC", "POR", "CRI",
        "SVE",
    ]

    // Decodes JSON off the main thread, then inserts into the provided context.
    // Must be called from MainActor (the view's .task or similar) so that context
    // operations happen on the right thread.
    static func seedIfNeeded(context: ModelContext) async {
        if UserDefaults.standard.bool(forKey: seededKey) {
            var check = FetchDescriptor<CachedCard>()
            check.fetchLimit = 1
            let storeEmpty = (try? context.fetch(check).isEmpty) ?? true
            if !storeEmpty {
                print("[BundledCardSeeder] skipped — already seeded (\(seededKey))")
                return
            }
            // Flag is set but store is empty — schema migration wiped the store without
            // clearing UserDefaults. Reset both flags and fall through to re-seed.
            print("[BundledCardSeeder] flag set but store empty — re-seeding")
            UserDefaults.standard.removeObject(forKey: seededKey)
            UserDefaults.standard.removeObject(forKey: CardRepository.lastRefreshKey)
        }
        print("[BundledCardSeeder] seeding from bundled JSON...")

        typealias SetCardPair = (releaseDate: Date?, cards: [CardSeedEntry])

        let pairs: [SetCardPair] = await Task.detached(priority: .userInitiated) {
            let decoder = JSONDecoder()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy/MM/dd"
            var result: [SetCardPair] = []
            result.reserveCapacity(20)
            for code in setFiles {
                guard
                    let url = Bundle.main.url(forResource: code, withExtension: "json"),
                    let data = try? Data(contentsOf: url),
                    let payload = try? decoder.decode(CardSetPayload.self, from: data)
                else { continue }
                let releaseDate = payload.set.releaseDate.flatMap { dateFormatter.date(from: $0) }
                result.append((releaseDate, payload.cards))
            }
            return result
        }.value

        for (releaseDate, cards) in pairs {
            for entry in cards {
                let maxDamage = entry.attacks
                    .compactMap { Int($0.damage.prefix(while: { $0.isNumber })) }
                    .max()
                let attackEnergyCosts = Set(entry.attacks.flatMap(\.cost)).sorted()
                let minAttackCost = entry.attacks.map { $0.cost.count }.min()
                let numericPrefix = Int(entry.number.prefix(while: { $0.isNumber })) ?? 0
                let numberSortKey = String(format: "%03d", numericPrefix) + entry.number

                let roleTags = CardTagClassifier.tags(
                    abilities: entry.abilities,
                    attacks: entry.attacks,
                    rulesText: entry.rulesText
                )
                context.insert(CachedCard(
                    id: entry.id,
                    name: entry.name,
                    supertype: entry.supertype,
                    setCode: entry.setCode,
                    setName: entry.setName,
                    number: entry.number,
                    types: entry.types,
                    subtypes: entry.subtypes,
                    hp: entry.hp,
                    isStandardLegal: entry.isStandardLegal,
                    imageURL: entry.imageURL,
                    largeImageURL: entry.largeImageURL,
                    rulesText: entry.rulesText,
                    regulationMark: entry.regulationMark,
                    rarity: entry.rarity,
                    hasAbility: !entry.abilities.isEmpty,
                    maxDamage: maxDamage,
                    attackEnergyCosts: attackEnergyCosts,
                    retreatCost: entry.retreatCost,
                    weaknessType: entry.weaknessType,
                    resistanceType: entry.resistanceType,
                    setReleaseDate: releaseDate,
                    numberSortKey: numberSortKey,
                    roleTags: roleTags,
                    minAttackCost: minAttackCost
                ))
            }
        }

        let total = pairs.reduce(0) { $0 + $1.cards.count }
        print("[BundledCardSeeder] inserting \(total) cards from \(pairs.count) sets")

#if DEBUG
        // QA: log top-5 role tag combinations for spot-checking classifier output.
        var tagComboCounts: [String: Int] = [:]
        for (_, cards) in pairs {
            for entry in cards {
                let combo = CardTagClassifier.tags(abilities: entry.abilities, attacks: entry.attacks, rulesText: entry.rulesText).joined(separator: "+")
                tagComboCounts[combo, default: 0] += 1
            }
        }
        let top5 = tagComboCounts.sorted { $0.value > $1.value }.prefix(5)
        print("[BundledCardSeeder] top-5 tag combos: \(top5.map { "\($0.key.isEmpty ? "(none)" : $0.key): \($0.value)" }.joined(separator: ", "))")
#endif

        try? context.save()
        print("[BundledCardSeeder] save complete")
        // Mark the card cache fresh so CardRepository skips the network sync on launch.
        UserDefaults.standard.set(Date(), forKey: CardRepository.lastRefreshKey)
        UserDefaults.standard.set(true, forKey: seededKey)
    }
}

// MARK: - CardTagClassifier

private enum CardTagClassifier {
    // Returns a sorted, deduplicated array of canonical role tag strings for a card.
    static func tags(abilities: [AbilitySeedEntry], attacks: [AttackSeedEntry], rulesText: [String] = []) -> [String] {
        let allTexts = abilities.map(\.text) + attacks.map(\.text) + rulesText
        var result: Set<String> = []

        for text in allTexts where !text.isEmpty {
            if text.localizedCaseInsensitiveContains("draw") && text.localizedCaseInsensitiveContains("card") {
                result.insert("Draw")
            }
            if text.localizedCaseInsensitiveContains("search your deck") || text.localizedCaseInsensitiveContains("look at the top") {
                result.insert("Search")
            }
            if text.localizedCaseInsensitiveContains("from your discard pile") {
                result.insert("Recovery")
            }
            if (text.localizedCaseInsensitiveContains("attach") && text.localizedCaseInsensitiveContains("energy"))
                || (text.localizedCaseInsensitiveContains("move") && text.localizedCaseInsensitiveContains("energy")) {
                result.insert("Energy Acceleration")
            }
            if text.localizedCaseInsensitiveContains("heal")
                || text.range(of: "remove.*damage counter", options: [.regularExpression, .caseInsensitive]) != nil {
                result.insert("Healing")
            }
            if text.localizedCaseInsensitiveContains("less damage")
                || text.range(of: "prevent.*damage", options: [.regularExpression, .caseInsensitive]) != nil
                || text.range(of: "reduce.*damage", options: [.regularExpression, .caseInsensitive]) != nil
                || text.localizedCaseInsensitiveContains("prevent all effects") {
                result.insert("Damage Reduction")
            }
            if text.localizedCaseInsensitiveContains("more damage") || text.localizedCaseInsensitiveContains("additional damage") {
                result.insert("Damage Boost")
            }
            // "from your discard pile" describes retrieval — that's Recovery, not Disruption.
            let isRecoveryEffect = text.localizedCaseInsensitiveContains("from your discard pile")
            if !isRecoveryEffect && (
                text.localizedCaseInsensitiveContains("discard")
                || text.localizedCaseInsensitiveContains("lost zone")
                || text.localizedCaseInsensitiveContains("can't play")
                || text.localizedCaseInsensitiveContains("devolve")
                || (text.localizedCaseInsensitiveContains("shuffle") && text.contains("opponent's hand"))
                || (text.localizedCaseInsensitiveContains("opponent") && text.localizedCaseInsensitiveContains("cost") && text.localizedCaseInsensitiveContains("more"))
            ) {
                result.insert("Disruption")
            }
            // Status uses exact capitalised strings as printed on cards
            if text.contains("Poisoned") || text.contains("Burned") || text.contains("Paralyzed")
                || text.contains("Asleep") || text.contains("Confused") {
                result.insert("Status")
            }
            // Spread Damage uses exact capitalised strings for bench/each cases; regex for placed counters
            if (text.localizedCaseInsensitiveContains("damage counter")
                && (text.contains("Benched") || text.contains("each of your opponent's Pokémon")))
                || text.range(of: #"(?:put|place) \d+ damage counter"#, options: [.regularExpression, .caseInsensitive]) != nil {
                result.insert("Spread Damage")
            }
            // Gusting: forces the opponent's Active Pokémon to change.
            // Canonical pattern: "switch in" + "opponent" + "benched" — covers Boss's Orders,
            // Prime Catcher, attack-based gusts (Mawile, Braviary, etc.), and gusting abilities.
            // Cards that ALSO self-switch (Iron Bundle, Samurott, Giovanni) get both tags.
            let isGust = text.localizedCaseInsensitiveContains("switch in")
                && text.localizedCaseInsensitiveContains("opponent")
                && text.localizedCaseInsensitiveContains("benched")
            if isGust {
                result.insert("Gusting")
            }
            // Mobility: lets YOUR Active Pokémon retreat or switch freely.
            // The plain "switch" check is scoped to self-switch effects:
            //   - "switch your active" / "switch this pokémon with" → Item/ability self-switch
            //   - no "opponent" context + no "switch in" → basic Switch, Escape Rope, etc.
            // Pure gust cards (Boss's Orders, Prime Catcher) only hit the Gusting branch above.
            // A self-switch exists when the card explicitly moves YOUR Active Pokémon, or when
            // "switch" appears in any context that isn't the pure-gust pattern (isGust).
            // This correctly handles Escape Rope ("Your opponent switches first." contains
            // "opponent" but is not a gust card) and dual-effect cards like Prime Catcher.
            let hasSelfSwitch = text.localizedCaseInsensitiveContains("switch your active")
                || text.localizedCaseInsensitiveContains("switch this pokémon with")
                || text.localizedCaseInsensitiveContains("switch this pokemon with")
                || (text.localizedCaseInsensitiveContains("switch") && !isGust)
            if hasSelfSwitch
                || text.contains("no Retreat Cost")
                || (text.contains("Retreat Cost") && text.localizedCaseInsensitiveContains("less"))
                || (text.localizedCaseInsensitiveContains("shuffle") && text.contains("into your deck")) {
                result.insert("Mobility")
            }
            if text.contains("Prize card")
                && (text.localizedCaseInsensitiveContains("take") || text.localizedCaseInsensitiveContains("more")
                    || text.localizedCaseInsensitiveContains("fewer") || text.localizedCaseInsensitiveContains("additional")) {
                result.insert("Prize Control")
            }
            if text.localizedCaseInsensitiveContains("can't play")
                || text.localizedCaseInsensitiveContains("can't use")
                || text.localizedCaseInsensitiveContains("can't be put")
                || text.localizedCaseInsensitiveContains("can't be moved")
                || text.range(of: "lose.*Ability", options: [.regularExpression, .caseInsensitive]) != nil
                || text.contains("no Abilities") {
                result.insert("Lock")
            }
        }

        // Survivability — ability text only
        for text in abilities.map(\.text) where !text.isEmpty {
            if text.contains("not Knocked Out")
                || text.range(of: "remaining HP.*10", options: .regularExpression) != nil {
                result.insert("Survivability")
            }
        }

        return result.sorted()
    }
}

// MARK: - Codable payload matching the scraped JSON schema

private struct CardSetPayload: Decodable {
    let set: SetMetadataSeed
    let cards: [CardSeedEntry]
}

private struct SetMetadataSeed: Decodable {
    let releaseDate: String?
}

struct CardSeedEntry: Decodable, Sendable {
    let id: String
    let name: String
    let supertype: String
    let setCode: String
    let setName: String
    let number: String
    let types: [String]
    let subtypes: [String]
    let hp: Int?
    let isStandardLegal: Bool
    let imageURL: String
    let largeImageURL: String?
    let rulesText: [String]
    let regulationMark: String?
    let rarity: String?
    let attacks: [AttackSeedEntry]
    let abilities: [AbilitySeedEntry]
    let retreatCost: Int?
    let weaknessType: String?
    let resistanceType: String?

    private enum CodingKeys: String, CodingKey {
        case id, name, supertype, setCode, setName, number, types, subtypes, hp, isStandardLegal
        case imageURL, largeImageURL, rulesText, regulationMark, rarity, attacks, abilities
        case retreatCost, weaknessType, resistanceType
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        supertype = try c.decodeIfPresent(String.self, forKey: .supertype) ?? ""
        setCode = try c.decode(String.self, forKey: .setCode)
        setName = try c.decode(String.self, forKey: .setName)
        number = try c.decode(String.self, forKey: .number)
        types = try c.decodeIfPresent([String].self, forKey: .types) ?? []
        subtypes = try c.decodeIfPresent([String].self, forKey: .subtypes) ?? []
        hp = try c.decodeIfPresent(Int.self, forKey: .hp)
        isStandardLegal = try c.decode(Bool.self, forKey: .isStandardLegal)
        imageURL = try c.decode(String.self, forKey: .imageURL)
        largeImageURL = try c.decodeIfPresent(String.self, forKey: .largeImageURL)
        rulesText = try c.decodeIfPresent([String].self, forKey: .rulesText) ?? []
        regulationMark = try c.decodeIfPresent(String.self, forKey: .regulationMark)
        rarity = try c.decodeIfPresent(String.self, forKey: .rarity)
        attacks = try c.decodeIfPresent([AttackSeedEntry].self, forKey: .attacks) ?? []
        abilities = try c.decodeIfPresent([AbilitySeedEntry].self, forKey: .abilities) ?? []
        retreatCost = try c.decodeIfPresent(Int.self, forKey: .retreatCost)
        weaknessType = try c.decodeIfPresent(String.self, forKey: .weaknessType)
        resistanceType = try c.decodeIfPresent(String.self, forKey: .resistanceType)
    }
}

struct AttackSeedEntry: Decodable, Sendable {
    let name: String
    let cost: [String]
    let damage: String
    let text: String

    private enum CodingKeys: String, CodingKey { case name, cost, damage, text }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        cost = try c.decodeIfPresent([String].self, forKey: .cost) ?? []
        damage = try c.decodeIfPresent(String.self, forKey: .damage) ?? ""
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
    }
}

struct AbilitySeedEntry: Decodable, Sendable {
    let name: String
    let text: String

    private enum CodingKeys: String, CodingKey { case name, text }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
    }
}
