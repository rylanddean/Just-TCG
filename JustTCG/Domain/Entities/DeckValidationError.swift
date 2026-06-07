import Foundation

enum DeckValidationError: Identifiable {
    case tooManyCards(count: Int)
    case duplicateCard(name: String, count: Int)
    case illegalCard(name: String)
    case noBasicPokemon

    var id: String {
        switch self {
        case .tooManyCards: "total"
        case .duplicateCard(let name, _): "dup:\(name)"
        case .illegalCard(let name): "illegal:\(name)"
        case .noBasicPokemon: "noBasic"
        }
    }

    var isFatal: Bool {
        switch self {
        case .noBasicPokemon: false
        default: true
        }
    }

    var message: String {
        switch self {
        case .tooManyCards(let count):
            let diff = 60 - count
            return diff > 0
                ? "Need \(diff) more card\(diff == 1 ? "" : "s") (\(count)/60)"
                : "Too many cards (\(count)/60)"
        case .duplicateCard(let name, let count):
            return "\(name): \(count) copies (max 4)"
        case .illegalCard(let name):
            return "\(name) is not Standard-legal"
        case .noBasicPokemon:
            return "No Basic Pokémon in deck"
        }
    }

    // Card name to scroll to / highlight when the user taps this error.
    var affectedCardName: String? {
        switch self {
        case .duplicateCard(let name, _): name
        case .illegalCard(let name): name
        default: nil
        }
    }
}
