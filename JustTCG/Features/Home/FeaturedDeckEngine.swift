import Foundation

// MARK: - Candidate

struct FeaturedDeckCandidate {
    let tournament: LimitlessTournament
    let placement: LimitlessPlacement
}

// MARK: - Snapshot

struct FeaturedDeckSnapshot: Codable {
    let fetchedAt: Date
    let playerName: String
    let tournamentName: String
    let tournamentDate: Date
    let placing: Int
    let archetype: String
    let deckListId: String?
    let primaryCardNames: [String]

    func isStale(now: Date = .now) -> Bool {
        !Calendar.current.isDate(fetchedAt, inSameDayAs: now)
    }
}

// MARK: - Engine

struct FeaturedDeckEngine {
    static func pick(from candidates: [FeaturedDeckCandidate], date: Date = .now) -> FeaturedDeckSnapshot? {
        let pool = candidates.filter { $0.placement.rank <= 8 }
        guard !pool.isEmpty else { return nil }

        let ordinal = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        let chosen = pool[ordinal % pool.count]

        let primaryCardNames = chosen.placement.archetype
            .components(separatedBy: " / ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .prefix(3)
            .map { String($0) }

        return FeaturedDeckSnapshot(
            fetchedAt: date,
            playerName: chosen.placement.playerName,
            tournamentName: chosen.tournament.name,
            tournamentDate: chosen.tournament.date,
            placing: chosen.placement.rank,
            archetype: chosen.placement.archetype,
            deckListId: chosen.placement.deckListId,
            primaryCardNames: primaryCardNames
        )
    }
}
