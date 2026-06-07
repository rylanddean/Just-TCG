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
    var cachedAt: Date

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
        cachedAt: Date = .now
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
        self.cachedAt = cachedAt
    }
}
