import SwiftUI
import SwiftData

struct ConsistencySheet: View {
    let deck: Deck
    let deckCards: [DeckCard]

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var breakdown: ConsistencyBreakdown? = nil
    @State private var expandedCards: Set<String> = []
    @State private var mergedEntries: [DeckCardEntry] = []
    @State private var dealtHand: [(name: String, imageURL: String?)] = []

    private static let percentFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .percent
        f.maximumFractionDigits = 0
        return f
    }()

    var body: some View {
        NavigationStack {
            Group {
                if deckCards.isEmpty {
                    ContentUnavailableView("No cards in deck", systemImage: "rectangle.on.rectangle.slash")
                } else if let bd = breakdown {
                    contentView(bd)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Consistency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear { compute() }
    }

    // MARK: - Content

    private func contentView(_ bd: ConsistencyBreakdown) -> some View {
        List {
            summarySection(bd)
            openingHandSimSection
            oddsSection(bd)
            aboutSection
        }
    }

    // MARK: - Summary

    private func summarySection(_ bd: ConsistencyBreakdown) -> some View {
        Section("Summary") {
            HStack {
                Text("Consistency Score")
                Spacer()
                Text("\(bd.consistencyScore)")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(scoreColor(bd.consistencyScore))
            }
            HStack {
                Text("Draw cards")
                Spacer()
                Text("\(bd.drawCount) copies")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Search cards")
                Spacer()
                Text("\(bd.searchCount) copies")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Basic Pokémon in opening hand")
                Spacer()
                Text(formatPercent(bd.basicOpeningHandProbability))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(scoreColor(Int(bd.basicOpeningHandProbability * 100)))
            }
        }
    }

    // MARK: - Opening hand simulation

    private var openingHandSimSection: some View {
        Section("Opening Hand") {
            Button(dealtHand.isEmpty ? "Deal Opening Hand" : "Re-deal") { dealHand() }
            if !dealtHand.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(dealtHand.indices, id: \.self) { i in
                            let card = dealtHand[i]
                            VStack(spacing: 4) {
                                AsyncImage(url: URL(string: card.imageURL ?? "")) { phase in
                                    if case .success(let image) = phase {
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } else {
                                        RoundedRectangle(cornerRadius: 4).fill(.quaternary)
                                    }
                                }
                                .frame(width: 56, height: 78)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                Text(card.name)
                                    .font(.system(size: 9))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .frame(width: 56)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            }
        }
    }

    private func dealHand() {
        var pool: [(name: String, imageURL: String?)] = []
        for entry in mergedEntries {
            for _ in 0..<entry.copies {
                pool.append((name: entry.name, imageURL: entry.imageURL))
            }
        }
        pool.shuffle()
        dealtHand = Array(pool.prefix(7))
    }

    // MARK: - Opening hand odds

    private func oddsSection(_ bd: ConsistencyBreakdown) -> some View {
        Section("Opening Hand Odds") {
            ForEach(bd.keyCards, id: \.name) { card in
                cardOddsRow(card)
            }
        }
    }

    @ViewBuilder
    private func cardOddsRow(_ card: KeyCardOdds) -> some View {
        let isExpanded = expandedCards.contains(card.name)
        VStack(alignment: .leading, spacing: 4) {
            Button {
                if isExpanded { expandedCards.remove(card.name) }
                else          { expandedCards.insert(card.name) }
            } label: {
                HStack(spacing: 10) {
                    AsyncImage(url: URL(string: card.imageURL ?? "")) { phase in
                        if case .success(let image) = phase {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            RoundedRectangle(cornerRadius: 3).fill(.quaternary)
                        }
                    }
                    .frame(width: 28, height: 38)
                    .clipShape(RoundedRectangle(cornerRadius: 3))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.name)
                            .lineLimit(1)
                            .foregroundStyle(.primary)
                        Text("×\(card.copies)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    GeometryReader { _ in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.fill.tertiary)
                                .frame(width: 60, height: 8)
                            Capsule()
                                .fill(scoreColor(Int(card.openingHandProbability * 100)))
                                .frame(width: 60 * card.openingHandProbability, height: 8)
                        }
                    }
                    .frame(width: 60, height: 8)
                    Text(formatPercent(card.openingHandProbability))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    Text("By Turn 2 (going first): \(formatPercent(card.byTurn2First))")
                    Text("By Turn 2 (going second): \(formatPercent(card.byTurn2Second))")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
                .padding(.bottom, 4)
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            Text("Consistency Score (0–100) measures draw and search engine reliability in the first two turns. Basic Pokémon in Opening Hand shows the probability of drawing at least one Basic Pokémon in your opening 7 — a mulliganed opening hand is an automatic signal this is low. Opening Hand Odds use the hypergeometric distribution per card. Scores above 60 are generally tournament-ready.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Compute

    private func compute() {
        let repo = CardRepository(modelContext: context)
        let ids = deckCards.map { $0.cardId }
        let cachedCards = (try? repo.fetch(ids: ids)) ?? []
        let cardsByName: [String: CachedCard] = Dictionary(
            cachedCards.map { ($0.name, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let entries: [DeckCardEntry] = deckCards.compactMap { dc in
            guard let card = cachedCards.first(where: { $0.id == dc.cardId }) else { return nil }
            return DeckCardEntry(name: card.name, copies: dc.quantity, supertype: card.supertype,
                                 subtypes: card.subtypes, retreatCost: card.retreatCost,
                                 imageURL: card.imageURL, hasAbility: card.hasAbility,
                                 types: card.types, weaknessType: card.weaknessType,
                                 pokemonRole: dc.pokemonRole, minAttackCost: card.minAttackCost)
        }

        let merged: [DeckCardEntry] = Dictionary(grouping: entries, by: \.name).map { name, group in
            DeckCardEntry(
                name: name,
                copies: group.reduce(0) { $0 + $1.copies },
                supertype: group[0].supertype,
                subtypes: group[0].subtypes,
                retreatCost: group[0].retreatCost,
                imageURL: group[0].imageURL,
                hasAbility: group[0].hasAbility,
                types: group[0].types,
                weaknessType: group[0].weaknessType,
                pokemonRole: group[0].pokemonRole,
                minAttackCost: group[0].minAttackCost
            )
        }

        let roleTags: (String) -> [String] = { name in
            cardsByName[name]?.roleTags ?? []
        }

        mergedEntries = merged
        breakdown = ConsistencyEngine().breakdown(entries: merged, deckSize: 60, roleTags: roleTags)
    }

    // MARK: - Helpers

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case ..<40: return .red
        case 40..<60: return .orange
        case 60..<80: return .yellow
        default: return .green
        }
    }

    private func formatPercent(_ value: Double) -> String {
        if value < 0.01 { return "< 1%" }
        return Self.percentFormatter.string(from: NSNumber(value: value)) ?? "\(Int(value * 100))%"
    }
}

// MARK: - ConsistencyGauge

struct ConsistencyGauge: View {
    let score: Int
    var label: String = "Consistency"

    var body: some View {
        Gauge(value: Double(score), in: 0...100) {
            EmptyView()
        } currentValueLabel: {
            Text("\(score)")
                .font(.headline.bold())
        } minimumValueLabel: {
            EmptyView()
        } maximumValueLabel: {
            EmptyView()
        }
        .gaugeStyle(.accessoryCircular)
        .tint(Gradient(colors: [.red, .orange, .yellow, .green]))
        .overlay(alignment: .bottom) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .offset(y: 8)
        }
    }
}
