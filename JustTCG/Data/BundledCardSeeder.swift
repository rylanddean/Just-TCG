import Foundation
import SwiftData

// Seeds the SwiftData card cache from bundled JSON files on first launch.
// Subsequent launches skip this entirely (UserDefaults check is instant).
// When new regulation sets ship in an app update, bump seededKey's version suffix.
enum BundledCardSeeder {

    static let seededKey = "bundled_cards_seeded_v5"

    private static let setFiles = [
        "TEF", "TWM", "SFA", "SCR", "SSP",
        "PRE", "JTG", "DRI", "BLK", "WHT",
        "MEG", "PFL", "ASC", "POR", "CRI",
    ]

    // Decodes JSON off the main thread, then inserts into the provided context.
    // Must be called from MainActor (the view's .task or similar) so that context
    // operations happen on the right thread.
    static func seedIfNeeded(context: ModelContext) async {
        guard !UserDefaults.standard.bool(forKey: seededKey) else { return }

        typealias SetCardPair = (releaseDate: Date?, cards: [CardSeedEntry])

        let pairs: [SetCardPair] = await Task.detached(priority: .userInitiated) {
            let decoder = JSONDecoder()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy/MM/dd"
            var result: [SetCardPair] = []
            result.reserveCapacity(20)
            for code in setFiles {
                guard
                    let url = Bundle.main.url(forResource: code, withExtension: "json",
                                              subdirectory: "CardData"),
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
                let numericPrefix = Int(entry.number.prefix(while: { $0.isNumber })) ?? 0
                let numberSortKey = String(format: "%03d", numericPrefix) + entry.number

                context.insert(CachedCard(
                    id: entry.id,
                    name: entry.name,
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
                    numberSortKey: numberSortKey
                ))
            }
        }

        try? context.save()
        // Mark the card cache fresh so CardRepository skips the network sync on launch.
        UserDefaults.standard.set(Date(), forKey: CardRepository.lastRefreshKey)
        UserDefaults.standard.set(true, forKey: seededKey)
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
        case id, name, setCode, setName, number, types, subtypes, hp, isStandardLegal
        case imageURL, largeImageURL, rulesText, regulationMark, rarity, attacks, abilities
        case retreatCost, weaknessType, resistanceType
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
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
    let cost: [String]
    let damage: String

    private enum CodingKeys: String, CodingKey { case cost, damage }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cost = try c.decodeIfPresent([String].self, forKey: .cost) ?? []
        damage = try c.decodeIfPresent(String.self, forKey: .damage) ?? ""
    }
}

struct AbilitySeedEntry: Decodable, Sendable {
    let name: String
}
