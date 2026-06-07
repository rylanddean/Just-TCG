import Foundation
import SwiftData

@Model
final class FavouritePlayer {
    @Attribute(.unique) var id: String
    var name: String
    var country: String
    var addedAt: Date

    init(id: String, name: String, country: String, addedAt: Date = .now) {
        self.id = id
        self.name = name
        self.country = country
        self.addedAt = addedAt
    }
}
