import SwiftUI

struct AbilityCompatibilitySheet: View {
    let breakdown: AbilityCompatibilityBreakdown

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                scoreSection

                if breakdown.results.isEmpty {
                    ContentUnavailableView(
                        "No ability Pokémon",
                        systemImage: "pawprint",
                        description: Text("Add Pokémon with abilities to see compatibility analysis.")
                    )
                } else {
                    if breakdown.hasIssues {
                        issuesSection
                    }
                    if breakdown.results.contains(where: { $0.severity == .ok }) {
                        okSection
                    }
                    aboutSection
                }
            }
            .navigationTitle("Ability Compatibility")
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
                ConsistencyGauge(score: breakdown.compatibilityScore, label: "")
                    .frame(width: 96, height: 96)
                Text("ability compatibility")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Issues list

    private var issuesSection: some View {
        Section("Issues") {
            ForEach(breakdown.results.filter { $0.severity != .ok }, id: \.cardName) { result in
                issueRow(result)
            }
        }
    }

    private func issueRow(_ result: AbilityCompatibilityResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                severityIcon(result.severity)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(result.cardName)
                            .font(.body)
                        Text("×\(result.copies)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        scoreChip(score: result.score, severity: result.severity)
                    }
                    Text(result.abilityName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let warning = result.warningMessage {
                Text(warning)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 24)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - OK list

    private var okSection: some View {
        Section("No Issues") {
            ForEach(breakdown.results.filter { $0.severity == .ok }, id: \.cardName) { result in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.subheadline)
                    Text(result.cardName)
                        .font(.body)
                    Spacer()
                    Text(result.abilityName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            Text("Ability Compatibility scores how reliably each ability Pokémon in your deck can use its ability given the deck's composition. A score of 100 means every ability fires unconditionally or the deck easily satisfies any conditions. Scores fall when abilities require a minimum number of specific Pokémon in play, a named card that isn't in the deck, a specific energy type, or a Trainer that must be played that turn. Conflicts (red) mean the condition is almost never met; Cautions (orange) mean it's sometimes met but unreliably. The deck-level score loses 30 points per conflict and 15 per caution.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func severityIcon(_ severity: AbilitySeverity) -> some View {
        switch severity {
        case .conflict:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.subheadline)
        case .caution:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
                .font(.subheadline)
        case .ok:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.subheadline)
        }
    }

    private func scoreChip(score: Int, severity: AbilitySeverity) -> some View {
        let color: Color = severity == .conflict ? .red : (severity == .caution ? .orange : .green)
        return Text("\(score)")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: Capsule())
    }
}
