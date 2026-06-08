import Foundation
import SwiftData

enum DeckEditKind: String, Codable {
    case addCard, removeCard, setQuantity, rename
}

@Model
final class DeckEdit {
    var id: UUID
    var date: Date
    var kind: DeckEditKind
    var cardId: String?
    var cardName: String?
    var quantityBefore: Int
    var quantityAfter: Int
    var nameBefore: String?
    var nameAfter: String?
    var deck: Deck?

    init(
        date: Date = .now,
        kind: DeckEditKind,
        cardId: String? = nil,
        cardName: String? = nil,
        quantityBefore: Int = 0,
        quantityAfter: Int = 0,
        nameBefore: String? = nil,
        nameAfter: String? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.kind = kind
        self.cardId = cardId
        self.cardName = cardName
        self.quantityBefore = quantityBefore
        self.quantityAfter = quantityAfter
        self.nameBefore = nameBefore
        self.nameAfter = nameAfter
    }
}
