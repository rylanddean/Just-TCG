import Foundation

struct ProfileStats {
    let totalGames: Int
    let wins: Int
    let losses: Int
    let ties: Int
    let winRate: Double?
    let currentStreak: Int
    let longestWinStreak: Int
    let bestMatchup: MatchupStat?
    let worstMatchup: MatchupStat?
    let mostPlayedDeck: Deck?
    let topArchetypeFaced: String?
}

struct ProfileStatsEngine {

    func compute(matches: [Match], decks: [Deck]) -> ProfileStats {
        let wins   = matches.filter { $0.result == .win  }.count
        let losses = matches.filter { $0.result == .loss }.count
        let ties   = matches.filter { $0.result == .tie  }.count
        let total  = matches.count
        let winRate: Double? = total > 0 ? Double(wins) / Double(total) : nil

        let matchupStats = MatchupStatsEngine().compute(matches: matches)
        let qualified = matchupStats.filter { $0.sampleSize >= 5 }
        let best  = qualified.max(by: { $0.winRate < $1.winRate })
        let worst = qualified.min(by: { $0.winRate < $1.winRate })

        let mostPlayed = decks
            .filter { !$0.matches.isEmpty }
            .max(by: { $0.matches.count < $1.matches.count })

        let topArchetype = Dictionary(grouping: matches, by: { $0.opponentArchetype })
            .mapValues(\.count)
            .max(by: { $0.value < $1.value })?.key

        return ProfileStats(
            totalGames:      total,
            wins:            wins,
            losses:          losses,
            ties:            ties,
            winRate:         winRate,
            currentStreak:   currentStreak(from: matches),
            longestWinStreak: longestWinStreak(from: matches),
            bestMatchup:     best,
            worstMatchup:    worst,
            mostPlayedDeck:  mostPlayed,
            topArchetypeFaced: topArchetype
        )
    }

    private func currentStreak(from matches: [Match]) -> Int {
        let sorted = matches.sorted { $0.date > $1.date }
        guard let first = sorted.first else { return 0 }
        var streak = first.result == .win ? 1 : first.result == .loss ? -1 : 0
        guard streak != 0 else { return 0 }
        for match in sorted.dropFirst() {
            if streak > 0 && match.result == .win   { streak += 1 }
            else if streak < 0 && match.result == .loss { streak -= 1 }
            else { break }
        }
        return streak
    }

    private func longestWinStreak(from matches: [Match]) -> Int {
        let sorted = matches.sorted { $0.date < $1.date }
        var best = 0
        var current = 0
        for match in sorted {
            if match.result == .win { current += 1; best = max(best, current) }
            else { current = 0 }
        }
        return best
    }
}
