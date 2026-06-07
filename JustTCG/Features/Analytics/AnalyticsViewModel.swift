import Foundation
import SwiftData
import Observation

enum TimeFilter: String, CaseIterable {
    case allTime   = "All time"
    case last30    = "Last 30 days"
    case last90    = "Last 90 days"

    var since: Date? {
        switch self {
        case .allTime: return nil
        case .last30:  return Calendar.current.date(byAdding: .day, value: -30, to: .now)
        case .last90:  return Calendar.current.date(byAdding: .day, value: -90, to: .now)
        }
    }
}

@Observable
final class AnalyticsViewModel {

    var selectedDeck: Deck? = nil
    var timeFilter: TimeFilter = .allTime

    private let engine = MatchupStatsEngine()

    func stats(for matches: [Match]) -> [MatchupStat] {
        let filtered: [Match]
        if let since = timeFilter.since {
            filtered = matches.filter { $0.date >= since }
        } else {
            filtered = matches
        }
        return engine.compute(matches: filtered)
    }

    func overallRecord(for matches: [Match]) -> (wins: Int, losses: Int, ties: Int, winPct: Double) {
        let filtered: [Match]
        if let since = timeFilter.since {
            filtered = matches.filter { $0.date >= since }
        } else {
            filtered = matches
        }
        let record = engine.overallRecord(matches: filtered)
        let total = record.wins + record.losses + record.ties
        let pct = total > 0 ? Double(record.wins) / Double(total) * 100 : 0
        return (record.wins, record.losses, record.ties, pct)
    }

    func weeklyRecords(for matches: [Match]) -> [WeeklyRecord] {
        let filtered: [Match]
        if let since = timeFilter.since {
            filtered = matches.filter { $0.date >= since }
        } else {
            filtered = matches
        }
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filtered) { match -> Date in
            calendar.dateInterval(of: .weekOfYear, for: match.date)?.start ?? match.date
        }
        return grouped
            .map { weekStart, group in
                WeeklyRecord(
                    weekStart: weekStart,
                    wins:   group.filter { $0.result == .win  }.count,
                    losses: group.filter { $0.result == .loss }.count,
                    ties:   group.filter { $0.result == .tie  }.count
                )
            }
            .sorted { $0.weekStart < $1.weekStart }
    }

    func recentMatches(against archetype: String, in matches: [Match]) -> [Match] {
        matches
            .filter { $0.opponentArchetype == archetype }
            .sorted { $0.date > $1.date }
            .prefix(5)
            .map { $0 }
    }
}
