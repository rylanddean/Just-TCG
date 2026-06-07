import Foundation

struct MatchupStatsEngine {

    func compute(matches: [Match]) -> [MatchupStat] {
        let grouped = Dictionary(grouping: matches, by: \.opponentArchetype)
        return grouped.map { archetype, group in
            MatchupStat(
                archetype: archetype,
                wins:   group.filter { $0.result == .win  }.count,
                losses: group.filter { $0.result == .loss }.count,
                ties:   group.filter { $0.result == .tie  }.count
            )
        }
        .sorted { $0.sampleSize > $1.sampleSize }
    }

    func compute(matches: [Match], since: Date) -> [MatchupStat] {
        compute(matches: matches.filter { $0.date >= since })
    }

    func overallRecord(matches: [Match]) -> (wins: Int, losses: Int, ties: Int) {
        (
            wins:   matches.filter { $0.result == .win  }.count,
            losses: matches.filter { $0.result == .loss }.count,
            ties:   matches.filter { $0.result == .tie  }.count
        )
    }
}
