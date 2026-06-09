import SwiftUI

struct MatchupGoalDetailView: View {
    let goal: MatchupGoal
    @Environment(PrepPlanRepository.self) private var repo
    @State private var showLogSession = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    var body: some View {
        List {
            statsHeader
            sessionsSection
        }
        .navigationTitle(goal.archetypeName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Log Session") { showLogSession = true }
            }
        }
        .sheet(isPresented: $showLogSession) {
            LogPrepSessionSheet(goal: goal)
        }
    }

    // MARK: - Stats header

    private var statsHeader: some View {
        Section {
            HStack(spacing: 24) {
                statCell(value: "\(goal.completedCount)", label: "Sessions")
                if let wr = goal.winRate {
                    statCell(value: String(format: "%.0f%%", wr * 100), label: "Win rate")
                }
                statCell(value: "\(goal.completedCount)/\(goal.targetSessionCount)", label: "Goal")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title2.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: - Sessions

    private var sessionsSection: some View {
        Section("Sessions") {
            if goal.sessions.isEmpty {
                Text("No sessions logged yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(goal.sessions.sorted(by: { $0.playedAt > $1.playedAt })) { session in
                    sessionRow(session)
                }
                .onDelete { offsets in
                    let sorted = goal.sessions.sorted(by: { $0.playedAt > $1.playedAt })
                    offsets.forEach { repo.deleteSession(sorted[$0]) }
                }
            }
        }
    }

    private func sessionRow(_ session: PrepSession) -> some View {
        HStack(spacing: 12) {
            resultIcon(session.result)
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.dateFormatter.string(from: session.playedAt))
                    .font(.subheadline)
                if !session.notes.isEmpty {
                    Text(session.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func resultIcon(_ result: MatchResult) -> some View {
        switch result {
        case .win:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .loss:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        case .tie:
            Image(systemName: "minus.circle").foregroundStyle(.secondary)
        }
    }
}
