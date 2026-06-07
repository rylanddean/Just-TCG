import SwiftUI
import SwiftData

struct MatchHistoryView: View {
    let deck: Deck

    @Environment(\.modelContext) private var context

    @Query private var matches: [Match]

    @State private var matchPendingDelete: Match? = nil
    @State private var showDeleteConfirmation = false

    init(deck: Deck) {
        self.deck = deck
        let deckId = deck.id
        _matches = Query(
            filter: #Predicate<Match> { $0.deck?.id == deckId },
            sort: \Match.date,
            order: .reverse
        )
    }

    var body: some View {
        List {
            Section {
                recordHeader
            }
            Section {
                ForEach(matches) { match in
                    NavigationLink {
                        MatchDetailView(match: match)
                    } label: {
                        MatchRow(match: match)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            matchPendingDelete = match
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("Match History")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if matches.isEmpty {
                ContentUnavailableView(
                    "No Matches Yet",
                    systemImage: "sportscourt",
                    description: Text("Log a match to start tracking your results.")
                )
            }
        }
        .confirmationDialog(
            "Delete this match result?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let match = matchPendingDelete {
                    context.delete(match)
                    try? context.save()
                }
            }
            Button("Cancel", role: .cancel) {}
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
}

// MARK: - Match row

struct MatchRow: View {
    let match: Match

    var body: some View {
        HStack(spacing: 12) {
            resultPill(match.result)

            VStack(alignment: .leading, spacing: 2) {
                Text(match.opponentArchetype)
                    .font(.body)
                Text(eventLabel(match.eventType))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(match.date, style: .relative)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func resultPill(_ result: MatchResult) -> some View {
        let (label, color): (String, Color) = switch result {
        case .win:  ("W", .green)
        case .loss: ("L", .red)
        case .tie:  ("T", .secondary)
        }
        Text(label)
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 26, height: 26)
            .background(color, in: Circle())
    }

    private func eventLabel(_ event: EventType) -> String {
        switch event {
        case .casual:                   return "Casual"
        case .leagueChallenge:          return "League Challenge"
        case .regionals:                return "Regionals"
        case .internationalChampionship: return "Internationals"
        case .worldChampionship:        return "Worlds"
        }
    }
}
