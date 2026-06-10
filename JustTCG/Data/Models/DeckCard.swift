import Foundation
import SwiftData

enum PokemonRole: String, Codable {
    case attacker
    case tech
}

@Model
final class DeckCard {
    var cardId: String
    var quantity: Int
    var pokemonRole: PokemonRole?
    var deck: Deck?

    init(cardId: String, quantity: Int = 1) {
        self.cardId = cardId
        self.quantity = quantity
    }
}
