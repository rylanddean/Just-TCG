import Foundation

// MARK: - Card

struct LimitlessCard {
    let id: String
    let name: String
    let supertype: String
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

// MARK: - Player search result

struct LimitlessPlayerSearchResult: Identifiable {
    let id: String
    let name: String
    let country: String
    let rank: Int?
    let points: Int?
}

// MARK: - Player ranking sort

enum PlayerRankSort: String, CaseIterable, Equatable {
    case points       = "points"
    case earnings     = "money"
    case day2Finishes = "day2s"
    case top8Finishes = "cuts"

    var displayName: String {
        switch self {
        case .points:       return "Points"
        case .earnings:     return "Earnings"
        case .day2Finishes: return "Day 2 Finishes"
        case .top8Finishes: return "Top 8 Finishes"
        }
    }

    var columnLabel: String {
        switch self {
        case .points:       return "pts"
        case .earnings:     return "earned"
        case .day2Finishes: return "day 2s"
        case .top8Finishes: return "top 8s"
        }
    }
}

// MARK: - Player zone

enum PlayerZone: String, CaseIterable, Equatable {
    case global       = "all"
    case europe       = "eu"
    case northAmerica = "na"
    case latinAmerica = "la"
    case oceania      = "oc"
    case asia         = "asia"

    var displayName: String {
        switch self {
        case .global:       return "Global"
        case .europe:       return "Europe"
        case .northAmerica: return "North America"
        case .latinAmerica: return "Latin America"
        case .oceania:      return "Oceania"
        case .asia:         return "Asia"
        }
    }
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
