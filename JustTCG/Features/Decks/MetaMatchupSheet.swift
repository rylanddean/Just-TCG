import SwiftUI

struct MetaMatchupSheet: View {
    let breakdown: MetaMatchupBreakdown
    let deckEntries: [DeckCardEntry]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                scoreSection
                if breakdown.matchups.isEmpty {
                    ContentUnavailableView(
                        "No meta data",
                        systemImage: "chart.bar.xaxis",
                        description: Text("Load tournament data to calculate matchup scores.")
                    )
                } else {
                    matchupsSection
                    aboutSection
                }
            }
            .navigationTitle("Meta Matchup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Score summary

    private var scoreSection: some View {
        Section {
            VStack(spacing: 4) {
                ConsistencyGauge(score: breakdown.matchupScore, label: "")
                    .frame(width: 96, height: 96)
                Text("vs. top meta")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Matchup list

    private var matchupsSection: some View {
        Section("Matchups") {
            ForEach(breakdown.matchups) { entry in
                matchupRow(entry)
            }
        }
    }

    private func matchupRow(_ entry: MatchupEntry) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Circle()
                .fill(typeColor(entry.primaryType))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.archetypeName)
                    .font(.subheadline)
                if let source = entry.abilitySource {
                    Text("via \(source)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(String(format: "%.1f%% meta", entry.metaSharePercent))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(entry.reason)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            advantageBadge(entry.advantage)
        }
    }

    @ViewBuilder
    private func advantageBadge(_ advantage: MatchupAdvantage) -> some View {
        switch advantage {
        case .favoured:
            Label("Favoured", systemImage: "checkmark")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green, in: Capsule())
        case .even:
            Label("Even", systemImage: "equal")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray5), in: Capsule())
        case .unfavoured:
            Label("Unfavoured", systemImage: "xmark")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red, in: Capsule())
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            Text("Matchup Score (0–100) rates how your deck's type composition fares against the most-played archetypes in recent tournaments. 100 means a type advantage in every meta matchup weighted by popularity; 0 means you're consistently on the wrong side of the weakness chart. Ability-driven advantages (such as Fairy Zone) are factored in where known. A score above 65 is generally strong for the current meta.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Type colours

    private func typeColor(_ type: String) -> Color {
        switch type {
        case "Fire":       return .red
        case "Water":      return .blue
        case "Grass":      return .green
        case "Lightning":  return .yellow
        case "Psychic":    return .purple
        case "Fighting":   return .orange
        case "Darkness":   return Color(.darkGray)
        case "Metal":      return Color(.lightGray)
        case "Dragon":     return .indigo
        case "Colorless":  return Color(.systemGray3)
        default:           return .gray
        }
    }
}
