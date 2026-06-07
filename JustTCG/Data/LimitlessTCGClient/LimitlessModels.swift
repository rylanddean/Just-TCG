import Foundation

// MARK: - Card

struct LimitlessCard {
    let id: String
    let name: String
    let setCode: String
    let setName: String
    let number: String
    let types: [String]
    let subtypes: [String]
    let hp: Int?
    let isStandardLegal: Bool
    let imageURL: String
    let rulesText: [String]
}

// MARK: - Tournament list

struct LimitlessTournament {
    let id: String
    let name: String
    let date: Date
    let country: String
    let format: String
    let playerCount: Int
}

// MARK: - Tournament detail

struct LimitlessTournamentDetail {
    let id: String
    let placements: [LimitlessPlacement]
}

struct LimitlessPlacement {
    let rank: Int
    let playerName: String
    let country: String
    let archetype: String
    let deckListId: String?
}

// MARK: - Deck list

struct LimitlessDeckList {
    let listId: String
    let entries: [LimitlessDeckEntry]
}

struct LimitlessDeckEntry {
    let setCode: String
    let number: String
    let name: String
    let quantity: Int
}
