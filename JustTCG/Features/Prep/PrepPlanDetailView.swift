import SwiftUI
import SwiftData

struct PrepPlanDetailView: View {
    let plan: PrepPlan
    @Environment(PrepPlanRepository.self) private var repo
    @Query(sort: \Deck.updatedAt, order: .reverse) private var decks: [Deck]
    @State private var showAddGoal = false

    var body: some View {
        List {
            headerSection
            goalsSection
        }
        .navigationTitle(plan.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Add Matchup") { showAddGoal = true }
            }
        }
        .sheet(isPresented: $showAddGoal) {
            AddMatchupGoalSheet(plan: plan)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        Section {
            VStack(spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(plan.tournamentDate.formatted(date: .long, time: .omitted),
                              systemImage: "calendar")
                            .font(.subheadline)
                        daysUntilLabel
                    }
                    Spacer()
                    readinessGauge
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var daysUntilLabel: some View {
        let days = plan.daysUntilTournament
        let (label, color): (String, Color) = {
            if days < 0   { return ("Event passed",  .secondary) }
            if days == 0  { return ("Today",         .red)       }
            if days <= 1  { return ("Tomorrow",      .red)       }
            if days <= 7  { return ("In \(days) days", .orange)  }
            return              ("In \(days) days", .green)
        }()
        return Text(label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
    }

    private var readinessGauge: some View {
        Gauge(value: plan.overallProgress, in: 0...1) {
            EmptyView()
        } currentValueLabel: {
            Text(String(format: "%.0f%%", plan.overallProgress * 100))
                .font(.caption.bold())
        }
        .gaugeStyle(.accessoryCircular)
        .tint(Gradient(colors: [.red, .orange, .green]))
        .frame(width: 72, height: 72)
    }

    // MARK: - Goals

    private var goalsSection: some View {
        Section("Matchup Goals") {
            if plan.matchupGoals.isEmpty {
                Text("No matchup goals yet. Tap \"Add Matchup\" to get started.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(plan.matchupGoals.sorted(by: { $0.archetypeName < $1.archetypeName })) { goal in
                    NavigationLink {
                        MatchupGoalDetailView(goal: goal)
                    } label: {
                        GoalRow(goal: goal)
                    }
                }
                .onDelete { offsets in
                    let sorted = plan.matchupGoals.sorted(by: { $0.archetypeName < $1.archetypeName })
                    offsets.forEach { repo.removeGoal(sorted[$0]) }
                }
            }
        }
    }
}

// MARK: - Goal row

private struct GoalRow: View {
    let goal: MatchupGoal

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(goal.archetypeName)
                    .font(.body)
                Spacer()
                if goal.isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                if let wr = goal.winRate {
                    Text(String(format: "%.0f%% W", wr * 100))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 8) {
                ProgressView(value: Double(goal.completedCount), total: Double(goal.targetSessionCount))
                    .tint(goal.isComplete ? .green : .accentColor)
                Text("\(goal.completedCount) / \(goal.targetSessionCount) sessions")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
