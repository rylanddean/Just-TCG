import SwiftUI
import SwiftData
import UIKit

struct ImportDeckSheet: View {
    /// If set, the sheet pre-populates from this text instead of the clipboard.
    var deckListText: String? = nil
    /// Suggested deck name; editable by the user before importing.
    var initialDeckName: String = "Imported Deck"
    /// Called after a successful import so callers can cascade dismissals.
    var onImportCompleted: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Environment(MetaTrendEngine.self) private var metaTrendEngine

    @State private var deckName: String
    @State private var matches: [DeckImportMatch] = []
    @State private var isLoading = true
    @State private var swapEntry: DeckImportMatch? = nil
    @State private var cardPreview: CardImagePreview? = nil

    // Deck stats computed from resolved matches
    @State private var deckBreakdown: ConsistencyBreakdown? = nil
    @State private var matchupBreakdown: MetaMatchupBreakdown? = nil
    @State private var expandedSubScores: Set<String> = []

    init(
        deckListText: String? = nil,
        initialDeckName: String = "Imported Deck",
        onImportCompleted: (() -> Void)? = nil
    ) {
        self.deckListText = deckListText
        self.initialDeckName = initialDeckName
        self.onImportCompleted = onImportCompleted
        self._deckName = State(initialValue: initialDeckName)
    }

    private var matchedCount:   Int { matches.filter(\.isMatched).count }
    private var unmatchedCount: Int { matches.filter { !$0.isMatched }.count }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if matches.isEmpty {
                    emptyState
                } else {
                    importContent
                }
            }
            .navigationTitle("Import Deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { await loadFromClipboard() }
            .sheet(item: $swapEntry) { match in
                CardSwapSheet(entry: match.entry) { selectedCard in
                    if let idx = matches.firstIndex(where: { $0.id == match.id }) {
                        matches[idx].cardId = selectedCard.id
                        matches[idx].imageURL = selectedCard.imageURL
                        matches[idx].largeImageURL = selectedCard.largeImageURL
                    }
                    computeBreakdown()
                }
            }
            .sheet(item: $cardPreview) { preview in
                CardFullScreenPreview(preview: preview)
            }
        }
    }

    // MARK: - Sub-views

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clipboard")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No deck list found")
                .font(.title3.bold())
            Text("Copy a deck list to your clipboard, then come back.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var importContent: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    TextField("Deck Name", text: $deckName)
                    Text("\(matchedCount) matched · \(unmatchedCount) unmatched")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let bd = deckBreakdown {
                    deckStatsSection(bd)
                }

                Section {
                    ForEach(matches) { match in
                        matchRow(match)
                    }
                }
            }

            Button(action: performImport) {
                Text("Import Deck")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(matchedCount > 0 ? Color.accentColor : Color.secondary.opacity(0.4))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(matchedCount == 0)
            .padding()
        }
    }

    @ViewBuilder
    private func matchRow(_ match: DeckImportMatch) -> some View {
        if match.isMatched {
            matchRowContent(match)
        } else {
            Button { swapEntry = match } label: {
                matchRowContent(match)
            }
            .buttonStyle(.plain)
        }
    }

    private func matchRowContent(_ match: DeckImportMatch) -> some View {
        HStack(spacing: 10) {
            // Thumbnail — tappable for matched cards to show full-screen preview
            CardThumbnail(imageURL: match.imageURL) {
                if let url = match.imageURL {
                    cardPreview = CardImagePreview(
                        imageURL: url,
                        largeImageURL: match.largeImageURL
                    )
                }
            }

            Text("\(match.entry.quantity)×")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(match.entry.name)
                    .font(.body)
                Text("\(match.entry.setCode) \(match.entry.number)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(spacing: 2) {
                Image(systemName: match.isMatched ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(match.isMatched ? .green : .yellow)
                if !match.isMatched {
                    Text("Tap to fix")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .contentShape(Rectangle())
    }

    // MARK: - Actions

    private func loadFromClipboard() async {
        let text = deckListText ?? UIPasteboard.general.string ?? ""
        let entries = DeckListParser.parse(text)
        matches = DeckImportLookup().resolve(entries, in: context)
        isLoading = false
        computeBreakdown()

        // Load meta trends if needed, then recompute for the matchup score
        if metaTrendEngine.snapshots.isEmpty {
            try? await metaTrendEngine.loadTrends()
            computeBreakdown()
        }
    }

    private func performImport() {
        let name = deckName.trimmingCharacters(in: .whitespaces)
        let deck = Deck(name: name.isEmpty ? "Imported Deck" : name)
        context.insert(deck)

        for match in matches where match.isMatched {
            let card = DeckCard(cardId: match.cardId!, quantity: match.entry.quantity)
            context.insert(card)
            deck.cards.append(card)
        }

        deck.updatedAt = .now
        try? context.save()
        // If a completion handler is provided it owns the full dismissal chain;
        // otherwise just close this sheet.
        if let onImportCompleted {
            onImportCompleted()
        } else {
            dismiss()
        }
    }

    // MARK: - Deck stats computation

    private func computeBreakdown() {
        // Fetch the full CachedCard for every resolved match (one query per unique ID)
        var cardMap: [String: CachedCard] = [:]
        for match in matches {
            guard let cardId = match.cardId, cardMap[cardId] == nil else { continue }
            let id = cardId
            var descriptor = FetchDescriptor<CachedCard>(
                predicate: #Predicate { $0.id == id }
            )
            descriptor.fetchLimit = 1
            if let card = (try? context.fetch(descriptor))?.first {
                cardMap[cardId] = card
            }
        }

        let entries: [DeckCardEntry] = matches.compactMap { match in
            guard let cardId = match.cardId, let card = cardMap[cardId] else { return nil }
            return DeckCardEntry(
                name: card.name,
                copies: match.entry.quantity,
                supertype: card.supertype,
                subtypes: card.subtypes,
                retreatCost: card.retreatCost,
                imageURL: card.imageURL,
                hasAbility: card.hasAbility,
                types: card.types,
                weaknessType: card.weaknessType,
                minAttackCost: card.minAttackCost
            )
        }

        guard !entries.isEmpty else { deckBreakdown = nil; matchupBreakdown = nil; return }

        // Merge copies of the same card printed in different sets
        let merged: [DeckCardEntry] = Dictionary(grouping: entries, by: \.name).map { _, group -> DeckCardEntry in
            let first = group[0]
            return DeckCardEntry(
                name: first.name,
                copies: group.reduce(0) { $0 + $1.copies },
                supertype: first.supertype,
                subtypes: first.subtypes,
                retreatCost: first.retreatCost,
                imageURL: first.imageURL,
                hasAbility: first.hasAbility,
                types: first.types,
                weaknessType: first.weaknessType,
                minAttackCost: first.minAttackCost
            )
        }

        let roleTags: (String) -> [String] = { name in
            cardMap.values.first { $0.name == name }?.roleTags ?? []
        }

        deckBreakdown = ConsistencyEngine().breakdown(entries: merged, deckSize: 60, roleTags: roleTags)

        let shares = metaTrendEngine.snapshots.last?.archetypeShares ?? []
        if !shares.isEmpty {
            matchupBreakdown = MetaMatchupEngine().breakdown(
                deck: merged,
                metaShares: shares,
                cardByName: { name in cardMap.values.first { $0.name == name } }
            )
        }
    }

    // MARK: - Stats view sections

    @ViewBuilder
    private func deckStatsSection(_ bd: ConsistencyBreakdown) -> some View {
        Section("Deck Stats") {
            HStack {
                Spacer()
                ConsistencyGauge(score: bd.overallScore, label: "Overall")
                    .frame(width: 72, height: 72)
                Spacer()
                ConsistencyGauge(score: bd.consistencyScore, label: "Consistency")
                    .frame(width: 72, height: 72)
                Spacer()
                if let mb = matchupBreakdown {
                    ConsistencyGauge(score: mb.matchupScore, label: "Matchup")
                        .frame(width: 72, height: 72)
                    Spacer()
                }
            }
            .padding(.vertical, 4)
        }

        if let mb = matchupBreakdown,
           !mb.favouredAgainstTypes.isEmpty || !mb.unfavouredAgainstTypes.isEmpty {
            Section("Type Matchup") {
                if !mb.favouredAgainstTypes.isEmpty {
                    typeMatchupRow(label: "Strong against", types: mb.favouredAgainstTypes, isStrong: true)
                }
                if !mb.unfavouredAgainstTypes.isEmpty {
                    typeMatchupRow(label: "Weak against", types: mb.unfavouredAgainstTypes, isStrong: false)
                }
            }
        }

        Section("Deck Profile") {
            statsSubScoreRow("Ability Impact",         score: bd.abilityImpactScore,
                explainer: "How powerful your Pokémon ability package is.")
            statsSubScoreRow("Energy Setup",           score: bd.energyScore,
                explainer: energySetupExplainer(bd))
            statsSubScoreRow("Mobility",               score: bd.mobilityScore,
                explainer: "How easily Pokémon can move between Active and Bench.")
            statsSubScoreRow("Prize Resilience",       score: bd.prizeResilienceScore,
                explainer: "Share of single-prize Pokémon — higher means more KOs required to win.")
            statsSubScoreRow("Disruption Power",       score: bd.disruptionScore,
                explainer: "Cards that pressure the opponent's hand or board.")
            statsSubScoreRow("Evolution Reliability",  score: bd.evolutionScore,
                explainer: "How well your Basic counts support your evolution lines.")
            statsSubScoreRow("Recovery",               score: bd.recoveryScore,
                explainer: "Ability to retrieve key pieces from the discard pile.")
            statsSubScoreRow("Item Dependency",        score: bd.itemDependencyScore,
                explainer: "Percentage of Trainers that are Items — higher means more vulnerability to Item lock.",
                colorInverted: true)
        }
    }

    private func typeMatchupRow(label: String, types: [String], isStrong: Bool) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.subheadline)
            Spacer()
            HStack(spacing: 6) {
                ForEach(types, id: \.self) { type in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(typeColor(type))
                            .frame(width: 8, height: 8)
                        Text(type)
                            .font(.caption.bold())
                            .foregroundStyle(isStrong ? Color.green : Color.red)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((isStrong ? Color.green : Color.red).opacity(0.1), in: Capsule())
                }
            }
        }
    }

    private func statsSubScoreRow(
        _ title: String, score: Int,
        explainer: String, colorInverted: Bool = false
    ) -> some View {
        let isExpanded = expandedSubScores.contains(title)
        let barColor = colorInverted ? scoreColor(100 - score) : scoreColor(score)
        return VStack(alignment: .leading, spacing: 4) {
            Button {
                if isExpanded { expandedSubScores.remove(title) }
                else          { expandedSubScores.insert(title) }
            } label: {
                HStack(spacing: 10) {
                    Text(title).foregroundStyle(.secondary)
                    Spacer()
                    ZStack(alignment: .leading) {
                        Capsule().fill(.fill.tertiary).frame(width: 60, height: 6)
                        Capsule().fill(barColor)
                            .frame(width: max(2, CGFloat(score) / 100 * 60), height: 6)
                    }
                    Text("\(score)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(barColor)
                        .frame(width: 28, alignment: .trailing)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(explainer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
            }
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case ..<40: return .red
        case 40..<60: return .orange
        case 60..<80: return .yellow
        default: return .green
        }
    }

    private func energySetupExplainer(_ bd: ConsistencyBreakdown) -> String {
        var parts: [String] = []
        if bd.identifiedAttackerCopies > 0, let avg = bd.attackerAvgMinCost {
            let costStr = avg == avg.rounded() ? String(Int(avg)) : String(format: "%.1f", avg)
            parts.append("\(bd.identifiedAttackerCopies) attacker \(bd.identifiedAttackerCopies == 1 ? "copy" : "copies") averaging \(costStr) energy each.")
        } else {
            parts.append("No attackers identified — score based on raw energy and acceleration counts.")
        }
        parts.append("\(bd.energyCardCount) energy cards, \(bd.energyAccelCount) acceleration \(bd.energyAccelCount == 1 ? "card" : "cards").")
        parts.append("Score measures supply vs. demand: acceleration counts double.")
        return parts.joined(separator: " ")
    }

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
        default:           return .gray
        }
    }
}

// MARK: - Card thumbnail

/// Small card image with a tap callback. Shows a rounded-rect placeholder while loading
/// or when no URL is provided (unmatched cards).
private struct CardThumbnail: View {
    let imageURL: String?
    let onTap: () -> Void

    var body: some View {
        Group {
            if let url = imageURL, let imageURL = URL(string: url) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        placeholder
                    }
                }
                .frame(width: 44, height: 62)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .onTapGesture(perform: onTap)
            } else {
                placeholder
                    .frame(width: 44, height: 62)
            }
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(Color.secondary.opacity(0.15))
    }
}

// MARK: - Card full-screen preview

struct CardImagePreview: Identifiable {
    let id: String
    let imageURL: String
    let largeImageURL: String?

    init(imageURL: String, largeImageURL: String?) {
        self.id = largeImageURL ?? imageURL
        self.imageURL = imageURL
        self.largeImageURL = largeImageURL
    }
}

private struct CardFullScreenPreview: View {
    let preview: CardImagePreview
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            AsyncImage(url: URL(string: preview.largeImageURL ?? preview.imageURL)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(24)
                default:
                    ProgressView()
                        .tint(.white)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.white.opacity(0.25))
                    .padding(20)
            }
        }
        .presentationBackground(.black)
    }
}
