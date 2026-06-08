import SwiftUI
import SwiftData

struct GameLogListView: View {
    let deck: Deck

    @Environment(\.modelContext) private var context
    @Query private var games: [LiveGame]

    init(deck: Deck) {
        self.deck = deck
        let deckId = deck.id
        _games = Query(
            filter: #Predicate<LiveGame> { $0.deck?.id == deckId },
            sort: \LiveGame.startedAt,
            order: .reverse
        )
    }

    var body: some View {
        List {
            ForEach(games) { game in
                GameLogRow(game: game)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            context.delete(game)
                            try? context.save()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .navigationTitle("Game Logs")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if games.isEmpty {
                ContentUnavailableView(
                    "No Game Logs",
                    systemImage: "gamecontroller",
                    description: Text("Start a live game to record turn-by-turn tracking.")
                )
            }
        }
    }
}

// MARK: - Row

private struct GameLogRow: View {
    let game: LiveGame

    var body: some View {
        HStack(spacing: 12) {
            resultBadge

            VStack(alignment: .leading, spacing: 2) {
                Text(game.opponentArchetype.isEmpty ? "Unknown opponent" : game.opponentArchetype)
                    .font(.body)
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
        if turnCount > 0 {
            parts.append("\(turnCount) turn\(turnCount == 1 ? "" : "s")")
        }
        if let end = game.endedAt {
            let mins = Int(end.timeIntervalSince(game.startedAt)) / 60
            if mins > 0 { parts.append("\(mins) min") }
        } else {
            parts.append("Abandoned")
        }
        return Text(parts.joined(separator: "  ·  "))
    }
}
