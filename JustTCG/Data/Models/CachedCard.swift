import Foundation
import SwiftData

@Model
final class CachedCard {
    @Attribute(.unique) var id: String
    var name: String
    var setCode: String
    var setName: String
    var number: String
    var types: [String]
    var subtypes: [String]
    var hp: Int?
    var isStandardLegal: Bool
    var imageURL: String
    var largeImageURL: String?
    var rulesText: [String]
    var cachedAt: Date

    var regulationMark: String?
    var rarity: String?
    var hasAbility: Bool
    var maxDamage: Int?
    var attackEnergyCosts: [String]
    var retreatCost: Int?
    var weaknessType: String?
    var resistanceType: String?
    var setReleaseDate: Date?
    var numberSortKey: String

    init(
        id: String,
        name: String,
        setCode: String,
        setName: String,
        number: String,
        types: [String] = [],
        subtypes: [String] = [],
        hp: Int? = nil,
        isStandardLegal: Bool = true,
        imageURL: String,
        largeImageURL: String? = nil,
        rulesText: [String] = [],
        cachedAt: Date = .now,
        regulationMark: String? = nil,
        rarity: String? = nil,
        hasAbility: Bool = false,
        maxDamage: Int? = nil,
        attackEnergyCosts: [String] = [],
        retreatCost: Int? = nil,
        weaknessType: String? = nil,
        resistanceType: String? = nil,
        setReleaseDate: Date? = nil,
        numberSortKey: String = ""
    ) {
        self.id = id
        self.name = name
        self.setCode = setCode
        self.setName = setName
        self.number = number
        self.types = types
        self.subtypes = subtypes
        self.hp = hp
        self.isStandardLegal = isStandardLegal
        self.imageURL = imageURL
        self.largeImageURL = largeImageURL
        self.rulesText = rulesText
        self.cachedAt = cachedAt
        self.regulationMark = regulationMark
        self.rarity = rarity
        self.hasAbility = hasAbility
        self.maxDamage = maxDamage
        self.attackEnergyCosts = attackEnergyCosts
        self.retreatCost = retreatCost
        self.weaknessType = weaknessType
        self.resistanceType = resistanceType
        self.setReleaseDate = setReleaseDate
        self.numberSortKey = numberSortKey
    }

    convenience init(from card: LimitlessCard, cachedAt: Date = .now) {
        self.init(
            id: card.id,
            name: card.name,
            setCode: card.setCode,
            setName: card.setName,
            number: card.number,
            types: card.types,
            subtypes: card.subtypes,
            hp: card.hp,
            isStandardLegal: card.isStandardLegal,
            imageURL: card.imageURL,
            largeImageURL: card.largeImageURL,
            rulesText: card.rulesText,
            cachedAt: cachedAt
        )
    }

    func update(from card: LimitlessCard, now: Date = .now) {
        name = card.name
        setCode = card.setCode
        setName = card.setName
        number = card.number
        types = card.types
        subtypes = card.subtypes
        hp = card.hp
        isStandardLegal = card.isStandardLegal
        imageURL = card.imageURL
        largeImageURL = card.largeImageURL
        rulesText = card.rulesText
        cachedAt = now
    }
}
