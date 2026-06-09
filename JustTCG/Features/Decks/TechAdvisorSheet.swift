import SwiftUI
import SwiftData

struct TechAdvisorSheet: View {
    let deck: Deck

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(MetaTrendEngine.self) private var metaTrendEngine

    @State private var engineBox: AnyObject? = nil
    private let fallback = TechAdvisorEngineFallback()

    @State private var request: TechAdvisorRequest? = nil
    @State private var suggestions: [TechSuggestion] = []
    @State private var isLoaded = false
    @State private var error: TechAdvisorError? = nil
    @State private var isRegenerating = false
    @State private var addedCards: Set<String> = []
    @State private var toastMessage: String? = nil
    @State private var showMatchupContext = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Tech Suggestions")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
        }
        .overlay(alignment: .bottom) {
            if let msg = toastMessage {
                Text(msg)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.green, in: Capsule())
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .id(msg)
            }
        }
        .task {
            if #available(iOS 26, *), engineBox == nil {
                engineBox = TechAdvisorEngine()
            }
            await run()
        }
    }

    // MARK: - Main content

    @ViewBuilder
    private var content: some View {
        if #available(iOS 26, *), let engine = engineBox as? TechAdvisorEngine {
            if engine.isGenerating && !isLoaded {
                loadingView
            } else if let err = error ?? engine.lastError {
                errorView(err)
            } else if isLoaded {
                resultsList(engine: engine)
            } else {
                loadingView
            }
        } else if let err = error {
            errorView(err)
        } else {
            unavailableView
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView("Analysing your matchups…")
                .progressViewStyle(.circular)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var unavailableView: some View {
        ContentUnavailableView(
            "Requires iOS 26",
            systemImage: "cpu",
            description: Text("AI tech suggestions need Apple Intelligence, available on iOS 26+.")
        )
    }

    @ViewBuilder
    private func errorView(_ err: TechAdvisorError) -> some View {
        switch err {
        case .modelUnavailable:
            ContentUnavailableView(
                "Requires iOS 26",
                systemImage: "cpu",
                description: Text("AI tech suggestions need Apple Intelligence, available on iOS 26+.")
            )
        case .insufficientData:
            ContentUnavailableView(
                "Not Enough Data",
                systemImage: "chart.bar",
                description: Text("Log at least 5 matches with this deck to get tech suggestions.")
            )
        case .parseFailure:
            VStack(spacing: 16) {
                ContentUnavailableView(
                    "Something went wrong",
                    systemImage: "exclamationmark.circle",
                    description: Text("The advisor couldn't parse a response. Try regenerating.")
                )
                Button("Try Again") { Task { await run() } }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    @ViewBuilder
    private func resultsList(engine: some AnyObject) -> some View {
        let matchCount = request?.worstMatchups.reduce(0) { $0 + $1.gamesPlayed } ?? 0
        List {
            Section {
                Text("Based on your last \(matchCount) matches")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if !suggestions.isEmpty {
                matchupContextSection
                suggestionsSection
            }
        }
        .overlay {
            if isRegenerating {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                ProgressView()
                    .scaleEffect(1.4)
            }
        }
    }

    // MARK: - Matchup context

    private var matchupContextSection: some View {
        Section(isExpanded: $showMatchupContext) {
            if let req = request {
                ForEach(req.worstMatchups, id: \.archetypeName) { matchup in
                    matchupRow(matchup)
                }
            }
        } header: {
            Button {
                withAnimation { showMatchupContext.toggle() }
            } label: {
                HStack {
                    Text("Your Worst Matchups")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: showMatchupContext ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func matchupRow(_ matchup: MatchupSummary) -> some View {
        HStack(spacing: 12) {
            Text(matchup.archetypeName)
                .font(.subheadline)
            Spacer()
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.2))
                    Capsule().fill(winRateColor(matchup.winRate))
                        .frame(width: geo.size.width * matchup.winRate)
                }
            }
            .frame(width: 60, height: 8)
            Text("\(Int(matchup.winRate * 100))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(winRateColor(matchup.winRate))
                .frame(width: 34, alignment: .trailing)
        }
        .padding(.vertical, 2)
    }

    private func winRateColor(_ rate: Double) -> Color {
        if rate < 0.40 { return .red }
        if rate < 0.50 { return .orange }
        return .yellow
    }

    // MARK: - Suggestions

    private var suggestionsSection: some View {
        Section("Suggestions") {
            ForEach(suggestions) { suggestion in
                SuggestionRow(
                    suggestion: suggestion,
                    isAdded: addedCards.contains(suggestion.cardName),
                    onAdd: { addCard(suggestion) }
                )
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Done") { dismiss() }
        }
        if isLoaded && !suggestions.isEmpty {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Regenerate") { Task { await regenerate() } }
                    .disabled(isRegenerating)
            }
        }
    }

    // MARK: - Actions

    private func run() async {
        guard #available(iOS 26, *), let engine = engineBox as? TechAdvisorEngine else {
            error = .modelUnavailable
            return
        }
        let req = engine.buildRequest(
            deck: deck,
            context: context,
            trendSnapshots: metaTrendEngine.snapshots
        )
        guard let req else {
            error = .insufficientData
            return
        }
        request = req
        error = nil
        do {
            suggestions = try await engine.suggestTech(for: req)
            isLoaded = true
        } catch let e as TechAdvisorError {
            error = e
        } catch {
            self.error = .parseFailure(error.localizedDescription)
        }
    }

    private func regenerate() async {
        guard #available(iOS 26, *), let engine = engineBox as? TechAdvisorEngine,
              let req = request else { return }
        isRegenerating = true
        defer { isRegenerating = false }
        do {
            suggestions = try await engine.suggestTech(for: req)
        } catch let e as TechAdvisorError {
            error = e
        } catch {
            self.error = .parseFailure(error.localizedDescription)
        }
    }

    private func addCard(_ suggestion: TechSuggestion) {
        let name = suggestion.cardName
        let descriptor = FetchDescriptor<CachedCard>(
            predicate: #Predicate { $0.name.localizedStandardContains(name) }
        )
        guard let card = (try? context.fetch(descriptor))?.first else { return }
        let repo = DeckRepository(modelContext: context)
        for _ in 0..<suggestion.suggestedCount {
            repo.addCard(cardId: card.id, to: deck, isBasicEnergy: false, cardName: card.name)
        }
        addedCards.insert(suggestion.cardName)
        showToast("Added \(suggestion.suggestedCount)× \(card.name)")
    }

    private func showToast(_ message: String) {
        withAnimation {
            toastMessage = message
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { toastMessage = nil }
        }
    }
}

// MARK: - Suggestion Row

private struct SuggestionRow: View {
    let suggestion: TechSuggestion
    let isAdded: Bool
    let onAdd: () -> Void

    @Environment(\.modelContext) private var context
    @State private var cachedCard: CachedCard? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(suggestion.cardName)
                            .font(.headline)
                        Text("×\(suggestion.suggestedCount)")
                            .font(.caption.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15), in: Capsule())
                            .foregroundStyle(Color.accentColor)
                    }
                }
                Spacer()
                addButton
            }
            Text(suggestion.reasoning)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !suggestion.targetMatchups.isEmpty {
                targetMatchupChips
            }
            if let card = cachedCard {
                NavigationLink {
                    CardDetailView(card: card)
                } label: {
                    Text("View Card")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .task {
            let name = suggestion.cardName
            cachedCard = (try? context.fetch(
                FetchDescriptor<CachedCard>(predicate: #Predicate { $0.name.localizedStandardContains(name) })
            ))?.first
        }
    }

    @ViewBuilder
    private var addButton: some View {
        if isAdded {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title3)
        } else if cachedCard != nil {
            Button(action: onAdd) {
                Label("Add", systemImage: "plus.circle")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        } else {
            Text("Not in library")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var targetMatchupChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(suggestion.targetMatchups, id: \.self) { matchup in
                    Text(matchup)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.15), in: Capsule())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
