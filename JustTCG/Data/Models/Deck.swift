import Foundation
import SwiftData

@Model
final class Deck {
    var id: UUID
    var name: String
    var format: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade) var cards: [DeckCard] = []
    // matches relationship — fully populated in M3-01
    @Relationship(deleteRule: .cascade) var matches: [Match] = []

    init(name: String, format: String = "Standard") {
        self.id = UUID()
        self.name = name
        self.format = format
        self.createdAt = .now
        self.updatedAt = .now
    }
}
