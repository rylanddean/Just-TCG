import SwiftUI
import SwiftData

struct TournamentPrepView: View {
    var isEmbedded: Bool = false

    @Environment(PrepPlanRepository.self) private var repo
    @Query(sort: \Deck.updatedAt, order: .reverse) private var decks: [Deck]

    @State private var showNewPlan = false

    var body: some View {
        if isEmbedded {
            content
        } else {
            NavigationStack { content }
        }
    }

    private var content: some View {
        let plans = repo.fetchAll()
        return Group {
            if plans.isEmpty {
                ContentUnavailableView(
                    "No Prep Plans",
                    systemImage: "trophy",
                    description: Text("Create a plan to start tracking your tournament readiness.")
                )
            } else {
                List {
                    ForEach(plans) { plan in
                        NavigationLink {
                            PrepPlanDetailView(plan: plan)
                        } label: {
                            PrepPlanRow(plan: plan, decks: decks)
                        }
                    }
                    .onDelete { offsets in
                        offsets.forEach { repo.delete(plans[$0]) }
                    }
                }
            }
        }
        .navigationTitle("Tournament Prep")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showNewPlan = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showNewPlan) {
            NewPrepPlanSheet()
        }
    }
}

// MARK: - Plan row

private struct PrepPlanRow: View {
    let plan: PrepPlan
    let decks: [Deck]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(plan.name)
                    .font(.headline)
                Spacer()
                daysLabel
            }
            Text(deckName)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ProgressView(value: plan.overallProgress)
                    .tint(.accentColor)
                Text(String(format: "%.0f%% ready", plan.overallProgress * 100))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var deckName: String {
        guard let id = plan.deckID, let deck = decks.first(where: { $0.id == id }) else {
            return "No deck selected"
        }
        return deck.name
    }

    private var daysLabel: some View {
        let days = plan.daysUntilTournament
        let (label, color): (String, Color) = {
            if days < 0    { return ("Past",       .secondary) }
            if days <= 1   { return ("In \(days)d", .red)      }
            if days <= 7   { return ("In \(days)d", .orange)   }
            return              ("In \(days)d",  .green)
        }()
        return Text(label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
    }
}
