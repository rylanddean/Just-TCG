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
    let largeImageURL: String?
    let rulesText: [String]
}

// MARK: - Tournament tier

enum TournamentTier: String, Codable, CaseIterable, Identifiable {
    case worlds   = "Worlds"
    case ic       = "International"
    case regional = "Regional"
    case lc       = "League Challenge"

    var id: String { rawValue }

    var badgeColor: String {
        switch self {
        case .worlds:   return "gold"
        case .ic:       return "purple"
        case .regional: return "blue"
        case .lc:       return "gray"
        }
    }
}

// MARK: - Tournament list

struct LimitlessTournament: Codable, Identifiable {
    let id: String
    let name: String
    let date: Date
    let country: String
    let format: String
    let playerCount: Int

    var tier: TournamentTier {
        let lower = name.lowercased()
        if lower.contains("world")         { return .worlds }
        if lower.contains("international") { return .ic }
        if lower.contains("regional")      { return .regional }
        return .lc
    }
}

// MARK: - Tournament detail

struct LimitlessTournamentDetail: Codable {
    let id: String
    let placements: [LimitlessPlacement]
}

struct LimitlessPlacement: Identifiable, Codable {
    var id: Int { rank }
    let rank: Int
    let playerName: String
    let country: String
    let archetype: String
    let wins: Int
    let losses: Int
    let ties: Int
    let deckListId: String?
    let playerId: String?

    var hasDeckList: Bool { deckListId != nil }
}

// MARK: - Player profile

struct LimitlessPlayerProfile: Identifiable {
    let id: String
    let name: String
    let country: String
    let totalPoints: Int
    let totalPrizeMoney: Int
    let travelAwards: Int
    let topCuts: PlayerTopCuts
    let results: [PlayerTournamentResult]
}

struct PlayerTopCuts {
    let internationalWins: Int
    let internationalTop2: Int
    let internationalTop4: Int
    let internationalTop8: Int
    let regionalWins: Int
    let regionalTop2: Int
    let regionalTop4: Int
    let regionalTop8: Int
}

struct PlayerTournamentResult: Identifiable {
    let tournamentId: String
    let tournamentName: String
    let date: Date
    let placement: Int
    let record: String
    let archetype: String
    let points: Int
    let prizeMoney: Int?
    let deckListId: String?

    var id: String { "\(tournamentId)-\(placement)" }
}

// MARK: - Deck list

struct LimitlessDeckList: Codable {
    let listId: String
    let entries: [LimitlessDeckEntry]
}

struct LimitlessDeckEntry: Codable, Identifiable {
    var id: String { "\(setCode)-\(number)" }
    let setCode: String
    let number: String
    let name: String
    let quantity: Int
}
