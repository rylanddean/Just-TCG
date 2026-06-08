import Foundation
import SwiftData

enum DeckStatus: String, Codable {
    case building, playing, retired

    var label: String {
        switch self {
        case .building: return "Building"
        case .playing:  return "Playing"
        case .retired:  return "Retired"
        }
    }
}

@Model
final class Deck {
    var id: UUID
    var name: String
    var format: String
    var createdAt: Date
    var updatedAt: Date

    var coverCardIds: [String] = []
    // Existing records without a stored value are read as .playing (the property default).
    // New decks are set to .building explicitly in init.
    var status: DeckStatus = DeckStatus.playing

    @Relationship(deleteRule: .cascade) var cards: [DeckCard] = []
    @Relationship(deleteRule: .cascade) var matches: [Match] = []
    @Relationship(deleteRule: .cascade) var edits: [DeckEdit] = []

    init(name: String, format: String = "Standard") {
        self.id = UUID()
        self.name = name
        self.format = format
        self.createdAt = .now
        self.updatedAt = .now
        self.status = .building
    }
}
