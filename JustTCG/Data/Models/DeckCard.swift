import Foundation
import SwiftData

@Model
final class DeckCard {
    var cardId: String
    var quantity: Int
    var deck: Deck?

    init(cardId: String, quantity: Int = 1) {
        self.cardId = cardId
        self.quantity = quantity
    }
}
