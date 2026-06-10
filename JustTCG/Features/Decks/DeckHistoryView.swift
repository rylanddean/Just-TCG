import SwiftUI
import SwiftData

// MARK: - Unified history item

private enum HistoryItem: Identifiable {
    case liveGame(LiveGame)
    case manualMatch(Match)

    var id: String {
        switch self {
        case .liveGame(let game):   return "game-\(game.id)"
        case .manualMatch(let match): return "match-\(match.id)"
        }
    }

    var date: Date {
        switch self {
        case .liveGame(let game):   return game.startedAt
        case .manualMatch(let match): return match.date
        }
    }
}

// MARK: - View

struct DeckHistoryView: View {
    let deck: Deck

    @Environment(\.modelContext) private var context
    @Query private var matches: [Match]
    @Query private var games: [LiveGame]

    init(deck: Deck) {
        self.deck = deck
        let deckId = deck.id
        _matches = Query(
            filter: #Predicate<Match> { $0.deck?.id == deckId },
            sort: \Match.date,
            order: .reverse
        )
        _games = Query(
            filter: #Predicate<LiveGame> { $0.deck?.id == deckId },
            sort: \LiveGame.startedAt,
            order: .reverse
        )
    }

    // Deduplicated, reverse-chronological list:
    // Matches that have a linked LiveGame are represented only by their LiveGame row.
    private var items: [HistoryItem] {
        let linkedMatchIds = Set(games.compactMap { $0.match?.id })
        var result: [HistoryItem] = games.map { .liveGame($0) }
        for match in matches where !linkedMatchIds.contains(match.id) {
            result.append(.manualMatch(match))
        }
        return result.sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            Section { recordHeader }

            Section {
                ForEach(items) { item in
                    row(for: item)
                }
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if items.isEmpty {
                ContentUnavailableView(
                    "No History Yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Log a match or start a live game to begin tracking.")
                )
            }
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private func row(for item: HistoryItem) -> some View {
        switch item {
        case .liveGame(let game):
            liveGameRow(game)
        case .manualMatch(let match):
            NavigationLink {
                MatchDetailView(match: match)
            } label: {
                MatchRow(match: match)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) { delete(match: match) } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    @ViewBuilder
    private func liveGameRow(_ game: LiveGame) -> some View {
        let content = LiveGameHistoryRow(game: game)
        if let match = game.match {
            NavigationLink {
                MatchDetailView(match: match)
            } label: {
                content
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) { delete(game: game) } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        } else {
            content
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) { delete(game: game) } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
        }
    }

    // MARK: - Record header

    private var recordHeader: some View {
        let wins   = matches.filter { $0.result == .win }.count
        let losses = matches.filter { $0.result == .loss }.count
        let ties   = matches.filter { $0.result == .tie }.count
        return HStack(spacing: 0) {
            recordStat(value: wins,   label: "W", color: .green)
            Text("–").foregroundStyle(.secondary).padding(.horizontal, 4)
            recordStat(value: losses, label: "L", color: .red)
            Text("–").foregroundStyle(.secondary).padding(.horizontal, 4)
            recordStat(value: ties,   label: "T", color: .secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func recordStat(value: Int, label: String, color: Color) -> some View {
        Text("\(value)\(label)")
            .font(.title3.weight(.semibold))
            .foregroundStyle(color)
    }

    // MARK: - Delete actions

    private func delete(match: Match) {
        context.delete(match)
        try? context.save()
    }

    private func delete(game: LiveGame) {
        // Also delete the linked Match to avoid orphaned records
        if let match = game.match { context.delete(match) }
        context.delete(game)
        try? context.save()
    }
}

// MARK: - Live game history row

private struct LiveGameHistoryRow: View {
    let game: LiveGame

    var body: some View {
        HStack(spacing: 12) {
            resultBadge

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(game.opponentArchetype.isEmpty ? "Unknown opponent" : game.opponentArchetype)
                        .font(.body)
                    Text("Live")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                        .foregroundStyle(Color.accentColor)
                }
                subtitleText
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(game.startedAt, style: .relative)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var resultBadge: some View {
        if let result = game.match?.result {
            let (label, color): (String, Color) = switch result {
            case .win:  ("W", .green)
            case .loss: ("L", .red)
            case .tie:  ("T", Color(.secondaryLabel))
            }
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(color, in: Circle())
        } else {
            Image(systemName: "slash.circle")
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
        }
    }

    private var subtitleText: Text {
        var parts: [String] = []
        let turnCount = game.turns.count
        if turnCount > 0 { parts.append("\(turnCount) turn\(turnCount == 1 ? "" : "s")") }
        if let end = game.endedAt {
            let mins = Int(end.timeIntervalSince(game.startedAt)) / 60
            if mins > 0 { parts.append("\(mins) min") }
        } else {
            parts.append("Abandoned")
        }
        return Text(parts.joined(separator: "  ·  "))
    }
}
