import SwiftUI

struct MetaArchetypeDetailView: View {
    let row: MetaComparisonRow
    let allMatches: [Match]

    private var archetypeMatches: [Match] {
        allMatches
            .filter { $0.opponentArchetype.lowercased().trimmingCharacters(in: .whitespaces)
                      == row.archetype.lowercased().trimmingCharacters(in: .whitespaces) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            metaContextSection
            matchHistorySection
        }
        .navigationTitle(row.archetype)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Meta context

    private var metaContextSection: some View {
        Section("Tournament Meta") {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Meta share")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f%%", row.metaShare))
                        .font(.title2.weight(.semibold))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Events sampled")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(row.tournamentCount)")
                        .font(.title2.weight(.semibold))
                }
            }
            .padding(.vertical, 4)

            if let status = row.status {
                statusRow(status)
            }
        }
    }

    @ViewBuilder
    private func statusRow(_ status: MetaStatus) -> some View {
        let (label, icon, color): (String, String, Color) = switch status {
        case .ready:           ("Ready",           "checkmark.shield.fill", .green)
        case .danger:          ("Danger",          "exclamationmark.shield.fill", .red)
        case .practiceNeeded:  ("Practice needed", "figure.mind.and.body", .orange)
        }
        Label(label, systemImage: icon)
            .foregroundStyle(color)
            .font(.subheadline.weight(.medium))
    }

    // MARK: - Match history

    @ViewBuilder
    private var matchHistorySection: some View {
        Section("Your Matches vs \(row.archetype)") {
            if archetypeMatches.isEmpty {
                Text("No matches logged against this archetype.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(archetypeMatches) { match in
                    NavigationLink { MatchDetailView(match: match) } label: {
                        MatchRow(match: match)
                    }
                }
            }
        }
    }
}
