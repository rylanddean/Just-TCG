import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var allMatches: [Match]
    @Query(sort: \Deck.updatedAt, order: .reverse) private var decks: [Deck]
    @AppStorage("playerName") private var playerName = "Player"
    @State private var isEditingName = false
    @State private var nameDraft = ""

    private var stats: ProfileStats {
        ProfileStatsEngine().compute(matches: allMatches, decks: decks)
    }

    private var memberSince: Date? {
        let dates = allMatches.map(\.date) + decks.map(\.createdAt)
        return dates.min()
    }

    var body: some View {
        NavigationStack {
            Group {
                if allMatches.isEmpty && decks.isEmpty {
                    emptyState
                } else {
                    profileContent
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Profile content

    private var profileContent: some View {
        List {
            headerSection
            statsGridSection
            if stats.mostPlayedDeck != nil { mostPlayedSection }
            matchupsSection
            if stats.topArchetypeFaced != nil { topOpponentSection }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.accentColor)

                if isEditingName {
                    HStack {
                        TextField("Player name", text: $nameDraft)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.center)
                        Button("Save") {
                            let trimmed = nameDraft.trimmingCharacters(in: .whitespaces)
                            if !trimmed.isEmpty { playerName = trimmed }
                            isEditingName = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    Button {
                        nameDraft = playerName
                        isEditingName = true
                    } label: {
                        Text(playerName)
                            .font(.title3.bold())
                    }
                    .buttonStyle(.plain)
                }

                if let since = memberSince {
                    Text("Since \(since.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .listRowBackground(Color.clear)
    }

    // MARK: - Stats grid

    private var statsGridSection: some View {
        Section("Stats") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                StatCell(title: "Games",      value: "\(stats.totalGames)")
                StatCell(title: "Win Rate",   value: stats.winRate.map { String(format: "%.1f%%", $0 * 100) } ?? "—")
                StatCell(title: "Streak",     value: streakLabel(stats.currentStreak))
                StatCell(title: "Best Streak", value: stats.longestWinStreak > 0 ? "\(stats.longestWinStreak)W" : "—")
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Most played deck

    @ViewBuilder
    private var mostPlayedSection: some View {
        if let deck = stats.mostPlayedDeck {
            let wins = deck.matches.filter { $0.result == .win }.count
            let total = deck.matches.count
            Section("Most Played Deck") {
                VStack(alignment: .leading, spacing: 4) {
                    Text(deck.name)
                        .font(.headline)
                    Text("\(total) games · \(total > 0 ? String(format: "%.0f%%", Double(wins) / Double(total) * 100) : "—") win rate")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Matchups

    private var matchupsSection: some View {
        Section("Matchups") {
            if let best = stats.bestMatchup {
                LabeledContent("Best matchup") {
                    Text("\(best.archetype) · \(String(format: "%.0f%%", best.winRate * 100))")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }
            }
            if let worst = stats.worstMatchup {
                LabeledContent("Toughest matchup") {
                    Text("\(worst.archetype) · \(String(format: "%.0f%%", worst.winRate * 100))")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
            }
            if stats.bestMatchup == nil && stats.worstMatchup == nil {
                Text("Minimum 5 games against the same archetype")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Top opponent

    @ViewBuilder
    private var topOpponentSection: some View {
        if let top = stats.topArchetypeFaced {
            Section {
                LabeledContent("Most faced", value: top)
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ContentUnavailableView(
            "No Data Yet",
            systemImage: "person.crop.circle",
            description: Text("Log your first match to start building your profile.")
        )
    }

    // MARK: - Helpers

    private func streakLabel(_ streak: Int) -> String {
        if streak == 0 { return "—" }
        return streak > 0 ? "\(streak)W" : "\(abs(streak))L"
    }
}

// MARK: - StatCell

private struct StatCell: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.weight(.semibold).monospacedDigit())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 10))
    }
}
