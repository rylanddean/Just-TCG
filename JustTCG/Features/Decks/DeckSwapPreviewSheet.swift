import SwiftUI

struct DeckSwapPreviewSheet: View {
    let outCard: CachedCard
    let outCopies: Int
    let baseEntries: [DeckCardEntry]
    let allCards: [CachedCard]
    let onCommit: (CachedCard) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var searchResults: [CachedCard] = []
    @State private var selectedCandidate: CachedCard? = nil
    @State private var baseBreakdown: ConsistencyBreakdown? = nil
    @State private var previewBreakdown: ConsistencyBreakdown? = nil
    @State private var cachedLookup: [String: [String]] = [:]

    var body: some View {
        NavigationStack {
            List {
                removingHeader

                Section {
                    TextField("Search replacement cards…", text: $searchText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                if let candidate = selectedCandidate,
                   let base = baseBreakdown,
                   let preview = previewBreakdown {
                    previewSection(candidate: candidate, base: base, preview: preview)
                }

                if !searchResults.isEmpty {
                    Section("Results") {
                        ForEach(searchResults, id: \.id) { card in
                            resultRow(card)
                        }
                    }
                } else if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                    Section {
                        Text("No cards found for '\(searchText)'.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Swap Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Swap") {
                        if let candidate = selectedCandidate {
                            onCommit(candidate)
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedCandidate == nil)
                }
            }
            .task {
                // Build lookup on the main thread (SwiftData objects are main-actor bound).
                // Use reduce-into to safely handle same-named cards across different sets.
                var lookup: [String: [String]] = [:]
                for card in allCards { lookup[card.name] = card.roleTags }
                cachedLookup = lookup

                let entries = baseEntries
                let result = await Task.detached(priority: .userInitiated) {
                    ConsistencyEngine().breakdown(entries: entries, deckSize: 60, roleTags: { lookup[$0] ?? [] })
                }.value
                baseBreakdown = result
            }
            .onChange(of: searchText) { _, text in
                searchResults = filteredCards(text)
            }
            .onChange(of: selectedCandidate?.id) { _, _ in
                recomputePreview()
            }
        }
    }

    // MARK: - Subviews

    private var removingHeader: some View {
        Section {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: outCard.imageURL)) { phase in
                    if case .success(let img) = phase {
                        img.resizable().aspectRatio(contentMode: .fit)
                    } else {
                        RoundedRectangle(cornerRadius: 4).fill(.quaternary).aspectRatio(7/10, contentMode: .fit)
                    }
                }
                .frame(width: 34)
                .clipShape(RoundedRectangle(cornerRadius: 4))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Removing")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(outCard.name)
                        .font(.body.weight(.medium))
                    Text("×\(outCopies)  ·  \(outCard.setName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func previewSection(candidate: CachedCard, base: ConsistencyBreakdown, preview: ConsistencyBreakdown) -> some View {
        Section {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: candidate.imageURL)) { phase in
                    if case .success(let img) = phase {
                        img.resizable().aspectRatio(contentMode: .fit)
                    } else {
                        RoundedRectangle(cornerRadius: 4).fill(.quaternary).aspectRatio(7/10, contentMode: .fit)
                    }
                }
                .frame(width: 34)
                .clipShape(RoundedRectangle(cornerRadius: 4))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Replacing with")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(candidate.name)
                        .font(.body.weight(.medium))
                    Text(candidate.setName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)

            scoreDiffRow("Overall",        before: base.overallScore,       after: preview.overallScore)
            scoreDiffRow("Consistency",    before: base.consistencyScore,   after: preview.consistencyScore)
            scoreDiffRow("Ability Impact", before: base.abilityImpactScore, after: preview.abilityImpactScore)
            scoreDiffRow("Energy Setup",   before: base.energyScore,        after: preview.energyScore)
            scoreDiffRow("Mobility",       before: base.mobilityScore,      after: preview.mobilityScore)
            scoreDiffRow("Disruption",     before: base.disruptionScore,    after: preview.disruptionScore)
            scoreDiffRow("Recovery",       before: base.recoveryScore,      after: preview.recoveryScore)
            scoreDiffRow("Durability",     before: base.durabilityScore,    after: preview.durabilityScore)
        } header: {
            Text("Swap Preview")
        }
    }

    private func scoreDiffRow(_ label: String, before: Int, after: Int) -> some View {
        let delta = after - before
        let color: Color = delta > 0 ? .green : delta < 0 ? .red : .secondary
        let arrow = delta > 0 ? "arrow.up" : delta < 0 ? "arrow.down" : "minus"
        let deltaText = delta > 0 ? "+\(delta)" : "\(delta)"
        return HStack(spacing: 8) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(before)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text("\(after)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(delta == 0 ? Color.secondary : color)
            HStack(spacing: 2) {
                Image(systemName: arrow)
                    .font(.system(size: 9, weight: .bold))
                Text(deltaText)
                    .font(.caption.weight(.semibold).monospacedDigit())
            }
            .foregroundStyle(color)
            .frame(width: 40, alignment: .trailing)
        }
    }

    private func resultRow(_ card: CachedCard) -> some View {
        let isSelected = selectedCandidate?.id == card.id
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedCandidate = isSelected ? nil : card
            }
        } label: {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: card.imageURL)) { phase in
                    if case .success(let img) = phase {
                        img.resizable().aspectRatio(contentMode: .fit)
                    } else {
                        RoundedRectangle(cornerRadius: 4).fill(.quaternary).aspectRatio(7/10, contentMode: .fit)
                    }
                }
                .frame(width: 34, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 4))

                VStack(alignment: .leading, spacing: 2) {
                    Text(card.name).font(.body)
                    Text("\(card.setName) · #\(card.number)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tint)
                    .opacity(isSelected ? 1 : 0)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Logic

    private func filteredCards(_ query: String) -> [CachedCard] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        return allCards
            .filter { $0.name.localizedStandardContains(q) && $0.id != outCard.id }
            .sorted { $0.name < $1.name }
            .prefix(50)
            .map { $0 }
    }

    private func recomputePreview() {
        guard let candidate = selectedCandidate else {
            previewBreakdown = nil
            return
        }
        var entries = baseEntries

        // Remove out card
        if let idx = entries.firstIndex(where: { $0.name == outCard.name }) {
            let e = entries[idx]
            let remaining = e.copies - outCopies
            if remaining <= 0 {
                entries.remove(at: idx)
            } else {
                entries[idx] = DeckCardEntry(
                    name: e.name, copies: remaining, supertype: e.supertype,
                    subtypes: e.subtypes, retreatCost: e.retreatCost, imageURL: e.imageURL,
                    hasAbility: e.hasAbility, types: e.types, weaknessType: e.weaknessType,
                    pokemonRole: e.pokemonRole, minAttackCost: e.minAttackCost, hp: e.hp
                )
            }
        }

        // Add candidate — build a DeckCardEntry from value types extracted while still on main thread
        let candidateEntry = DeckCardEntry(
            name: candidate.name, copies: outCopies, supertype: candidate.supertype,
            subtypes: candidate.subtypes, retreatCost: candidate.retreatCost,
            imageURL: candidate.imageURL, hasAbility: candidate.hasAbility,
            types: candidate.types, weaknessType: candidate.weaknessType,
            pokemonRole: nil, minAttackCost: candidate.minAttackCost, hp: candidate.hp
        )
        if let idx = entries.firstIndex(where: { $0.name == candidate.name }) {
            let e = entries[idx]
            entries[idx] = DeckCardEntry(
                name: e.name, copies: e.copies + outCopies, supertype: e.supertype,
                subtypes: e.subtypes, retreatCost: e.retreatCost, imageURL: e.imageURL,
                hasAbility: e.hasAbility, types: e.types, weaknessType: e.weaknessType,
                pokemonRole: e.pokemonRole, minAttackCost: e.minAttackCost, hp: e.hp
            )
        } else {
            entries.append(candidateEntry)
        }

        let lookup = cachedLookup
        Task.detached(priority: .userInitiated) {
            let result = ConsistencyEngine().breakdown(entries: entries, deckSize: 60, roleTags: { lookup[$0] ?? [] })
            await MainActor.run { previewBreakdown = result }
        }
    }
}
