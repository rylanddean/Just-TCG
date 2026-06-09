import Foundation
import SwiftData

@Model
final class FavouritePlayer {
    @Attribute(.unique) var id: String
    var name: String
    var country: String
    var addedAt: Date
    var lastKnownPoints: Int?
    var lastKnownRank: Int?

    init(id: String, name: String, country: String, lastKnownPoints: Int? = nil, lastKnownRank: Int? = nil, addedAt: Date = .now) {
        self.id = id
        self.name = name
        self.country = country
        self.lastKnownPoints = lastKnownPoints
        self.lastKnownRank = lastKnownRank
        self.addedAt = addedAt
    }
}
