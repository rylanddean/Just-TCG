import Foundation

struct LiveGameStatsEngine {

    func averageDuration(games: [LiveGame]) -> TimeInterval? {
        let durations = games.compactMap { game -> TimeInterval? in
            guard let end = game.endedAt else { return nil }
            return end.timeIntervalSince(game.startedAt)
        }
        guard !durations.isEmpty else { return nil }
        return durations.reduce(0, +) / Double(durations.count)
    }

    func averageTurnsPerGame(games: [LiveGame]) -> Double? {
        let completed = games.filter { $0.endedAt != nil && !$0.turns.isEmpty }
        guard !completed.isEmpty else { return nil }
        return Double(completed.reduce(0) { $0 + $1.turns.count }) / Double(completed.count)
    }

    func averagePlayerTurnDuration(game: LiveGame) -> TimeInterval? {
        let durations = game.turns
            .filter { $0.isPlayerTurn && $0.endedAt != nil }
            .compactMap(\.duration)
        guard !durations.isEmpty else { return nil }
        return durations.reduce(0, +) / Double(durations.count)
    }

    func averageOpponentTurnDuration(game: LiveGame) -> TimeInterval? {
        let durations = game.turns
            .filter { !$0.isPlayerTurn && $0.endedAt != nil }
            .compactMap(\.duration)
        guard !durations.isEmpty else { return nil }
        return durations.reduce(0, +) / Double(durations.count)
    }

    func prizeProgressionSeries(game: LiveGame) -> [(turn: Int, playerPrizes: Int, opponentPrizes: Int)] {
        game.turns
            .sorted { $0.turnNumber < $1.turnNumber }
            .map { (turn: $0.turnNumber, playerPrizes: $0.playerPrizesAtStart, opponentPrizes: $0.opponentPrizesAtStart) }
    }

    func longestTurn(game: LiveGame) -> (turnNumber: Int, duration: TimeInterval)? {
        let completed = game.turns.filter { $0.endedAt != nil }
        guard let longest = completed.max(by: { ($0.duration ?? 0) < ($1.duration ?? 0) }),
              let d = longest.duration else { return nil }
        return (turnNumber: longest.turnNumber, duration: d)
    }
}

extension TimeInterval {
    var mmssDisplay: String {
        let m = Int(max(0, self)) / 60
        let s = Int(max(0, self)) % 60
        return String(format: "%d:%02d", m, s)
    }

    var durationDisplay: String {
        let total = Int(max(0, self))
        let m = total / 60
        let s = total % 60
        return m > 0 ? "\(m)m \(s)s" : "\(s)s"
    }
}
