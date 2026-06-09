import SwiftUI
import SwiftData

struct DeckBuilderView: View {
    let deck: Deck
    var showsDoneButton: Bool = false
    var onDone: (() -> Void)? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(MetaTrendEngine.self) private var metaTrendEngine

    @Query(filter: #Predicate<CachedCard> { $0.isStandardLegal })
    private var standardLegalCards: [CachedCard]

    @State private var viewModel: DeckBuilderViewModel? = nil
    @State private var isRenaming = false
    @State private var renameText = ""
    @FocusState private var renameFocused: Bool
    @State private var showCardPicker = false
    @State private var pickerFilter = CardFilterState()
    @State private var showLogMatch = false
    @State private var showEditLog = false
    @State private var showTimeline = false
    @State private var showLiveGameSetup = false
    @State private var liveGame: LiveGame? = nil
    @State private var showGameSavedBanner = false
    @State private var highlightedCardIds: Set<String> = []
    @State private var showCardScanner = false
    @State private var showConsistency = false
    @State private var showTechAdvisor = false
    @State private var showMatchupSheet = false
    @State private var deckBreakdown: ConsistencyBreakdown? = nil
    @State private var matchupBreakdown: MetaMatchupBreakdown? = nil
    @State private var mergedDeckEntries: [DeckCardEntry] = []
    @State private var allRecommendations: [CardRecommendation] = []
    @State private var dismissedRecommendationIds: Set<String> = []
    @State private var recommendationFocus: String = "Auto"
    @State private var narrative: String? = nil
    @State private var isGeneratingNarrative = false
    @State private var narrativeError: String? = nil
    @State private var expandedSubScores: Set<String> = []
    @State private var recommendationToPreview: CardRecommendation? = nil

    private var visibleRecommendations: [CardRecommendation] {
        Array(allRecommendations.prefix(recommendationFocus == "Auto" ? 10 : 3))
    }

    var body: some View {
        Group {
            if let vm = viewModel {
                builderList(vm: vm)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showCardPicker, onDismiss: { viewModel?.loadCards() }) {
            CardPickerView(deck: deck, initialFilter: pickerFilter)
        }
        .sheet(isPresented: $showLogMatch) {
            LogMatchSheet(deck: deck, modelContext: context)
        }
        .sheet(isPresented: $showEditLog) {
            DeckEditLogView(deck: deck)
        }
        .sheet(isPresented: $showTimeline) {
            DeckVersionTimelineView(deck: deck)
        }
        .sheet(isPresented: $showLiveGameSetup) {
            LiveGameSetupSheet(deck: deck) { game in
                liveGame = game
            }
        }
        .fullScreenCover(item: $liveGame) { game in
            LiveGameHUDView(game: game) { saved in
                liveGame = nil
                if saved { withAnimation { showGameSavedBanner = true } }
            }
        }
        .fullScreenCover(isPresented: $showCardScanner, onDismiss: { viewModel?.loadCards() }) {
            CardScannerView(deck: deck)
        }
        .sheet(isPresented: $showConsistency) {
            ConsistencySheet(deck: deck, deckCards: deck.cards)
        }
        .sheet(isPresented: $showTechAdvisor) {
            TechAdvisorSheet(deck: deck)
        }
        .sheet(isPresented: $showMatchupSheet) {
            if let mb = matchupBreakdown {
                MetaMatchupSheet(breakdown: mb, deckEntries: mergedDeckEntries)
            }
        }
        .sheet(item: $recommendationToPreview) { rec in
            RecommendationCardDetailSheet(rec: rec)
        }
        .overlay(alignment: .bottom) {
            if showGameSavedBanner {
                Text("Game saved")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.green, in: Capsule())
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(for: .seconds(2))
                        withAnimation { showGameSavedBanner = false }
                    }
            }
        }
        .task {
            if viewModel == nil {
                let vm = DeckBuilderViewModel(deck: deck, modelContext: context)
                vm.loadCards()
                viewModel = vm
                computeBreakdown(vm: vm)
            }
            if metaTrendEngine.snapshots.isEmpty {
                try? await metaTrendEngine.loadTrends()
            }
        }
    }

    // MARK: - Builder list

    @ViewBuilder
    private func builderList(vm: DeckBuilderViewModel) -> some View {
        ScrollViewReader { proxy in
            List {
                validationSection(vm: vm, proxy: proxy)
                deckStatsSection(vm: vm)
                recommendationsSection
                pokemonSection(vm: vm)
                supporterSection(vm: vm)
                itemSection(vm: vm)
                toolSection(vm: vm)
                stadiumSection(vm: vm)
                aceSpecSection(vm: vm)
                energySection(vm: vm)

                Section {
                    Button {
                        openPicker(filter: CardFilterState())
                    } label: {
                        Label("Add Cards", systemImage: "plus")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .alignmentGuide(.listRowSeparatorLeading) { d in d[.leading] }
                    Button {
                        showCardScanner = true
                    } label: {
                        Label("Scan Cards", systemImage: "camera.viewfinder")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .alignmentGuide(.listRowSeparatorLeading) { d in d[.leading] }
                }

                gameLogsSection
                matchesSection
            }
            .onChange(of: vm.totalCount) { _, _ in computeBreakdown(vm: vm) }
            .onChange(of: metaTrendEngine.snapshots.count) { _, _ in computeBreakdown(vm: vm) }
            .onChange(of: recommendationFocus) { _, _ in withAnimation { computeRecommendations() } }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent(vm: vm) }
        }
    }

    // MARK: - Game logs section

    private var gameLogsSection: some View {
        Section {
            NavigationLink {
                GameLogListView(deck: deck)
            } label: {
                Label("Game Logs", systemImage: "gamecontroller")
            }
        }
    }

    // MARK: - Matches section

    private var matchesSection: some View {
        let sorted = deck.matches.sorted { $0.date > $1.date }
        let preview = Array(sorted.prefix(5))
        return Section {
            if preview.isEmpty {
                Label("No matches logged yet", systemImage: "sportscourt")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(preview) { match in
                    NavigationLink {
                        MatchDetailView(match: match)
                    } label: {
                        MatchRow(match: match)
                    }
                }
                if sorted.count > 5 {
                    NavigationLink("See all \(sorted.count) matches") {
                        MatchHistoryView(deck: deck)
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
                }
            }
        } header: {
            Text("Match History")
        }
    }

    // MARK: - Validation banner

    @ViewBuilder
    private func validationSection(vm: DeckBuilderViewModel, proxy: ScrollViewProxy) -> some View {
        let errors = vm.validationErrors
        let fatals = errors.filter { $0.isFatal }
        let warnings = errors.filter { !$0.isFatal }

        Section {
            if errors.isEmpty {
                Label("Legal deck", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                ForEach(fatals) { err in
                    validationRow(err, color: .red, vm: vm, proxy: proxy)
                }
                ForEach(warnings) { err in
                    validationRow(err, color: .yellow, vm: vm, proxy: proxy)
                }
            }
        }
    }

    @ViewBuilder
    private func validationRow(
        _ error: DeckValidationError,
        color: Color,
        vm: DeckBuilderViewModel,
        proxy: ScrollViewProxy
    ) -> some View {
        let icon = error.isFatal ? "xmark.circle.fill" : "exclamationmark.triangle.fill"
        if let name = error.affectedCardName {
            Button {
                scrollToCards(named: name, vm: vm, proxy: proxy)
            } label: {
                Label(error.message, systemImage: icon)
                    .foregroundStyle(color)
            }
            .buttonStyle(.plain)
        } else {
            Label(error.message, systemImage: icon)
                .foregroundStyle(color)
        }
    }

    private func scrollToCards(named name: String, vm: DeckBuilderViewModel, proxy: ScrollViewProxy) {
        let ids = vm.cardIds(forName: name)
        guard let firstId = ids.first else { return }
        withAnimation { highlightedCardIds = Set(ids) }
        proxy.scrollTo(firstId, anchor: .center)
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            highlightedCardIds = []
        }
    }

    // MARK: - Card sections

    @ViewBuilder
    private func pokemonSection(vm: DeckBuilderViewModel) -> some View {
        if !vm.pokemonCards.isEmpty {
            Section(sectionTitle("Pokémon", cards: vm.pokemonCards)) {
                ForEach(vm.pokemonCards) { dc in
                    DeckCardRow(
                        deckCard: dc,
                        cachedCard: vm.cachedCards[dc.cardId],
                        isHighlighted: highlightedCardIds.contains(dc.cardId)
                    ) {
                        vm.setQuantity($0, for: dc)
                    }
                    .id(dc.cardId)
                }
                addMoreButton { openPicker(filter: CardFilterState(cardGroup: .pokemon)) }
            }
        }
    }

    @ViewBuilder
    private func supporterSection(vm: DeckBuilderViewModel) -> some View {
        if !vm.supporterCards.isEmpty {
            Section(sectionTitle("Supporter", cards: vm.supporterCards)) {
                ForEach(vm.supporterCards) { dc in
                    DeckCardRow(
                        deckCard: dc,
                        cachedCard: vm.cachedCards[dc.cardId],
                        isHighlighted: highlightedCardIds.contains(dc.cardId)
                    ) { vm.setQuantity($0, for: dc) }
                    .id(dc.cardId)
                }
                addMoreButton { openPicker(filter: CardFilterState(cardGroup: .supporter)) }
            }
        }
    }

    @ViewBuilder
    private func itemSection(vm: DeckBuilderViewModel) -> some View {
        if !vm.itemCards.isEmpty {
            Section(sectionTitle("Item", cards: vm.itemCards)) {
                ForEach(vm.itemCards) { dc in
                    DeckCardRow(
                        deckCard: dc,
                        cachedCard: vm.cachedCards[dc.cardId],
                        isHighlighted: highlightedCardIds.contains(dc.cardId)
                    ) { vm.setQuantity($0, for: dc) }
                    .id(dc.cardId)
                }
                addMoreButton { openPicker(filter: CardFilterState(cardGroup: .item)) }
            }
        }
    }

    @ViewBuilder
    private func toolSection(vm: DeckBuilderViewModel) -> some View {
        if !vm.toolCards.isEmpty {
            Section(sectionTitle("Tool", cards: vm.toolCards)) {
                ForEach(vm.toolCards) { dc in
                    DeckCardRow(
                        deckCard: dc,
                        cachedCard: vm.cachedCards[dc.cardId],
                        isHighlighted: highlightedCardIds.contains(dc.cardId)
                    ) { vm.setQuantity($0, for: dc) }
                    .id(dc.cardId)
                }
                addMoreButton { openPicker(filter: CardFilterState(cardGroup: .tool)) }
            }
        }
    }

    @ViewBuilder
    private func stadiumSection(vm: DeckBuilderViewModel) -> some View {
        if !vm.stadiumCards.isEmpty {
            Section(sectionTitle("Stadium", cards: vm.stadiumCards)) {
                ForEach(vm.stadiumCards) { dc in
                    DeckCardRow(
                        deckCard: dc,
                        cachedCard: vm.cachedCards[dc.cardId],
                        isHighlighted: highlightedCardIds.contains(dc.cardId)
                    ) { vm.setQuantity($0, for: dc) }
                    .id(dc.cardId)
                }
                addMoreButton { openPicker(filter: CardFilterState(cardGroup: .stadium)) }
            }
        }
    }

    @ViewBuilder
    private func aceSpecSection(vm: DeckBuilderViewModel) -> some View {
        if !vm.aceSpecCards.isEmpty {
            Section(sectionTitle("Ace Spec", cards: vm.aceSpecCards)) {
                ForEach(vm.aceSpecCards) { dc in
                    DeckCardRow(
                        deckCard: dc,
                        cachedCard: vm.cachedCards[dc.cardId],
                        isHighlighted: highlightedCardIds.contains(dc.cardId)
                    ) { vm.setQuantity($0, for: dc) }
                    .id(dc.cardId)
                }
                addMoreButton { openPicker(filter: CardFilterState(cardGroup: .aceSpec)) }
            }
        }
    }

    @ViewBuilder
    private func energySection(vm: DeckBuilderViewModel) -> some View {
        if !vm.energyCards.isEmpty {
            Section(sectionTitle("Energy", cards: vm.energyCards)) {
                ForEach(vm.energyCards) { dc in
                    DeckCardRow(
                        deckCard: dc,
                        cachedCard: vm.cachedCards[dc.cardId],
                        isHighlighted: highlightedCardIds.contains(dc.cardId)
                    ) {
                        vm.setQuantity($0, for: dc)
                    }
                    .id(dc.cardId)
                }
                addMoreButton { openPicker(filter: CardFilterState(cardGroup: .energy)) }
            }
        }
    }

    private func addMoreButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label("Add more", systemImage: "plus")
                .font(.subheadline)
                .foregroundStyle(Color.accentColor)
        }
    }

    private func sectionTitle(_ name: String, cards: [DeckCard]) -> String {
        let qty = cards.reduce(0) { $0 + $1.quantity }
        return "\(name) · \(qty)"
    }

    // MARK: - Recommendations

    private func computeRecommendations() {
        guard let bd = deckBreakdown else { return }
        let focus: String? = recommendationFocus == "Auto" ? nil : recommendationFocus
        allRecommendations = DeckRecommendationEngine().recommend(
            breakdown: bd,
            deckEntries: mergedDeckEntries,
            allCards: standardLegalCards,
            dismissedIds: dismissedRecommendationIds,
            focusedScoreLabel: focus
        )
    }

    private func dismissRecommendation(_ rec: CardRecommendation) {
        withAnimation {
            dismissedRecommendationIds.insert(rec.id)
            allRecommendations.removeAll { $0.id == rec.id }
        }
    }

    private func resetRecommendations() {
        withAnimation {
            dismissedRecommendationIds.removeAll()
            computeRecommendations()
        }
    }

    @ViewBuilder
    private var recommendationsSection: some View {
        let hasSomething = !visibleRecommendations.isEmpty
            || !dismissedRecommendationIds.isEmpty
            || recommendationFocus != "Auto"
        if deckBreakdown != nil, hasSomething {
            Section {
                if visibleRecommendations.isEmpty {
                    Label(
                        recommendationFocus == "Auto"
                            ? "No suggestions right now"
                            : "No more \(recommendationFocus) suggestions",
                        systemImage: "checkmark.circle"
                    )
                    .foregroundStyle(.secondary)
                    .alignmentGuide(.listRowSeparatorLeading) { d in d[.leading] }
                } else {
                    ForEach(visibleRecommendations) { rec in
                        recommendationRow(rec)
                    }
                }
            } header: {
                HStack(spacing: 6) {
                    Text("Recommendations")
                    Spacer()
                    // Focus filter chip
                    Menu {
                        Picker("Focus", selection: $recommendationFocus) {
                            Label("Auto", systemImage: "sparkles").tag("Auto")
                            Divider()
                            Label("Consistency", systemImage: "hand.draw").tag("Consistency")
                            Label("Ability Impact", systemImage: "pawprint.fill").tag("Ability Impact")
                            Label("Energy Setup", systemImage: "bolt.fill").tag("Energy Setup")
                            Label("Recovery", systemImage: "arrow.counterclockwise.circle.fill").tag("Recovery")
                            Label("Mobility", systemImage: "figure.run").tag("Mobility")
                            Label("Disruption", systemImage: "bolt.horizontal.fill").tag("Disruption")
                        }
                    } label: {
                        Text(recommendationFocus)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(recommendationFocus == "Auto" ? Color.secondary : Color.accentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                recommendationFocus == "Auto"
                                    ? Color(.secondarySystemFill)
                                    : Color.accentColor.opacity(0.12),
                                in: Capsule()
                            )
                    }
                    .textCase(nil)
                    if !dismissedRecommendationIds.isEmpty {
                        Button("Reset") { resetRecommendations() }
                            .font(.caption)
                            .textCase(nil)
                    }
                }
            } footer: {
                let remaining = allRecommendations.count - visibleRecommendations.count
                if remaining > 0 {
                    Text("\(remaining) more suggestion\(remaining == 1 ? "" : "s") available — dismiss any card to see them")
                        .font(.caption)
                }
            }
        }
    }


    private func recommendationRow(_ rec: CardRecommendation) -> some View {
        HStack(spacing: 0) {
            // Tappable area — opens card detail sheet
            Button {
                recommendationToPreview = rec
            } label: {
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: rec.card.imageURL)) { phase in
                        if case .success(let img) = phase {
                            img.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.quaternary)
                                .aspectRatio(7/10, contentMode: .fit)
                        }
                    }
                    .frame(width: 34, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(rec.card.name)
                            .font(.body)
                            .lineLimit(1)
                            .foregroundStyle(.primary)
                        Text(rec.reason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(rec.scoreLabel)
                        .font(.caption2.weight(.medium))
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(.fill.tertiary, in: Capsule())
                        .padding(.trailing, 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Dismiss button — isolated tap zone
            Button {
                dismissRecommendation(rec)
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 36, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 2)
        .alignmentGuide(.listRowSeparatorLeading) { d in d[.leading] }
    }

    // MARK: - Deck stats section

    private func computeBreakdown(vm: DeckBuilderViewModel) {
        let entries = deck.cards.compactMap { dc -> DeckCardEntry? in
            guard let card = vm.cachedCards[dc.cardId] else { return nil }
            return DeckCardEntry(name: card.name, copies: dc.quantity, supertype: card.supertype,
                                 subtypes: card.subtypes, retreatCost: card.retreatCost,
                                 imageURL: card.imageURL, hasAbility: card.hasAbility,
                                 types: card.types, weaknessType: card.weaknessType)
        }
        guard !entries.isEmpty else { return }
        let merged = Dictionary(grouping: entries, by: \.name).map { name, group in
            DeckCardEntry(name: name,
                          copies: group.reduce(0) { $0 + $1.copies },
                          supertype: group[0].supertype,
                          subtypes: group[0].subtypes,
                          retreatCost: group[0].retreatCost,
                          imageURL: group[0].imageURL,
                          hasAbility: group[0].hasAbility,
                          types: group[0].types,
                          weaknessType: group[0].weaknessType)
        }
        let roleTags: (String) -> [String] = { name in
            vm.cachedCards.values.first { $0.name == name }?.roleTags ?? []
        }
        mergedDeckEntries = merged
        deckBreakdown = ConsistencyEngine().breakdown(entries: merged, deckSize: 60, roleTags: roleTags)
        let shares = metaTrendEngine.snapshots.last?.archetypeShares ?? []
        if !shares.isEmpty {
            let cardByName: (String) -> CachedCard? = { name in
                vm.cachedCards.values.first { $0.name == name }
            }
            matchupBreakdown = MetaMatchupEngine().breakdown(
                deck: merged, metaShares: shares, cardByName: cardByName
            )
        }
        computeRecommendations()
    }

    @ViewBuilder
    private func deckStatsSection(vm: DeckBuilderViewModel) -> some View {
        if let bd = deckBreakdown {
            Section {
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
                            .onTapGesture { showMatchupSheet = true }
                        Spacer()
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Deck Stats")
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
                statsSubScoreRow(
                    "Ability Impact", score: bd.abilityImpactScore,
                    explainer: "How powerful your Pokémon ability package is. Scores each ability Pokémon by the competitive value of its role tags — draw engines and search rank highest (e.g. Bibarel, Pidgeot ex), followed by energy acceleration, prize control, and lock effects, then disruption and recovery, with mobility and healing lowest. Running multiple copies and multiple distinct ability roles increases the score."
                )
                statsSubScoreRow(
                    "Energy Setup", score: bd.energyScore,
                    explainer: "How reliably you can power up attackers, based on energy acceleration cards (attaching multiple energy per turn) and your total energy count. A low score means you depend on naturally drawing into energy each game."
                )
                statsSubScoreRow(
                    "Mobility", score: bd.mobilityScore,
                    explainer: "How easily your Pokémon can move between Active and Bench. Scores switching cards and abilities (Switch, Escape Rope, Float Stone, free-retreat abilities) plus the average retreat cost of your Pokémon — lower retreat costs increase the score."
                )
                statsSubScoreRow(
                    "Prize Resilience", score: bd.prizeResilienceScore,
                    explainer: "The share of your Pokémon that are single-prize cards. Higher means your opponent needs more KOs to close out prizes. A score of 0 means every Pokémon is a Rule Box card — your opponent only needs 3 KOs to win. A score of 100 means all single-prize."
                )
                statsSubScoreRow(
                    "Disruption Power", score: bd.disruptionScore,
                    explainer: "How many cards you run to disrupt the opponent's hand, board, or strategy — Iono, Judge, Boss's Orders, Lost Zone effects, and similar. Higher means more pressure on your opponent each turn."
                )
                statsSubScoreRow(
                    "Evolution Reliability", score: bd.evolutionScore,
                    explainer: "How well-structured your evolution lines are. Basic-only decks score 100. Stage 1 and Stage 2 decks are scored on whether your Basic counts and middle-stage Pokémon (or Rare Candy) adequately cover your top-of-line counts. Thin lines like 1-1-1 score poorly."
                )
                statsSubScoreRow(
                    "Recovery", score: bd.recoveryScore,
                    explainer: "How well you can retrieve Pokémon, Supporters, and Energy from the discard pile. Cards like Night Stretcher, Pal Pad, and Super Rod contribute here. A low score means once key pieces are discarded, they're gone for the game."
                )
                statsSubScoreRow(
                    "Item Dependency", score: bd.itemDependencyScore,
                    explainer: "The percentage of your Trainer engine that is Item cards rather than Supporters. A higher score means more vulnerability to Item-lock effects from cards like Froslass ex. Most competitive decks score 60–80%. Not a flaw by itself — but worth knowing before facing lock strategies.",
                    colorInverted: true
                )
            }

            if #available(iOS 26, *) {
                builderAnalysisSection(bd)
            }
        }
    }

    private func typeMatchupRow(label: String, types: [String], isStrong: Bool) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(label)
                .font(.subheadline)
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
                    .background(
                        (isStrong ? Color.green : Color.red).opacity(0.1),
                        in: Capsule()
                    )
                }
            }
        }
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
        case "Colorless":  return Color(.systemGray3)
        default:           return .gray
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
                    Text(title)
                        .foregroundStyle(.secondary)
                    Spacer()
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.fill.tertiary)
                            .frame(width: 60, height: 6)
                        Capsule()
                            .fill(barColor)
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

    @available(iOS 26, *)
    private func builderAnalysisSection(_ bd: ConsistencyBreakdown) -> some View {
        Section {
            if let text = narrative {
                Text(text).font(.subheadline)
                Button("Regenerate") { generateBuilderNarrative(bd) }
                    .font(.subheadline).foregroundStyle(.secondary)
            } else if isGeneratingNarrative {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Analysing…").font(.subheadline).foregroundStyle(.secondary)
                }
            } else {
                if let err = narrativeError {
                    Text(err).font(.caption).foregroundStyle(.red)
                }
                Button {
                    generateBuilderNarrative(bd)
                } label: {
                    Label("Analyse with Apple Intelligence", systemImage: "sparkles")
                }
            }
        } header: {
            Label("Deck Analysis", systemImage: "sparkles")
        }
    }

    private func generateBuilderNarrative(_ bd: ConsistencyBreakdown) {
        guard #available(iOS 26, *) else { return }
        isGeneratingNarrative = true
        narrative = nil
        narrativeError = nil
        Task {
            defer { isGeneratingNarrative = false }
            do {
                narrative = try await ConsistencyNarrativeEngine().generate(for: bd, deckName: deck.name)
            } catch {
                narrativeError = error.localizedDescription
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private func toolbarContent(vm: DeckBuilderViewModel) -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button { showConsistency = true } label: {
                Image(systemName: "chart.bar.xaxis")
            }
        }
        ToolbarItem(placement: .navigationBarLeading) {
            Button { showTechAdvisor = true } label: {
                Image(systemName: "wand.and.stars")
            }
            .disabled(deck.matches.count < 5)
            .help("Log at least 5 matches to unlock tech suggestions")
        }
        ToolbarItem(placement: .principal) {
            if isRenaming {
                TextField("Deck name", text: $renameText)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .font(.headline)
                    .focused($renameFocused)
                    .onSubmit { commitRename(vm: vm) }
                    .onChange(of: renameFocused) { _, focused in
                        if !focused { commitRename(vm: vm) }
                    }
            } else {
                VStack(spacing: 2) {
                    Button(deck.name) {
                        renameText = deck.name
                        isRenaming = true
                        renameFocused = true
                    }
                    .font(.headline)
                    .foregroundStyle(.primary)
                    Text("\(vm.totalCount) / 60")
                        .font(.caption2)
                        .foregroundStyle(vm.totalCount == 60 ? .green : .red)
                }
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button { showLiveGameSetup = true } label: {
                    Label("Start Live Game", systemImage: "play.circle")
                }
                Button { showTimeline = true } label: {
                    Label("Version Timeline", systemImage: "chart.bar.doc.horizontal")
                }
                Button { showEditLog = true } label: {
                    Label("Edit History", systemImage: "clock.arrow.circlepath")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button { showLogMatch = true } label: {
                Image(systemName: "plus")
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            if showsDoneButton {
                Button("Done") { if let onDone { onDone() } else { dismiss() } }
                    .fontWeight(.semibold)
            } else {
                ShareLink(item: vm.exportString) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
    }

    private func openPicker(filter: CardFilterState) {
        pickerFilter = filter
        showCardPicker = true
    }

    private func commitRename(vm: DeckBuilderViewModel) {
        vm.rename(to: renameText)
        isRenaming = false
    }
}

// MARK: - Deck card row

private struct DeckCardRow: View {
    let deckCard: DeckCard
    let cachedCard: CachedCard?
    var isHighlighted: Bool = false
    let onQuantityChange: (Int) -> Void

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: cachedCard?.imageURL ?? "")) { phase in
                switch phase {
                case .success(let img):
                    img.resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                default:
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))
                        .aspectRatio(7/10, contentMode: .fit)
                }
            }
            .frame(width: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(cachedCard?.name ?? deckCard.cardId)
                    .font(.body)
                if let card = cachedCard {
                    Text("\(card.setName) · #\(card.number)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 10) {
                Button {
                    onQuantityChange(deckCard.quantity - 1)
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)

                Text("\(deckCard.quantity)")
                    .font(.body.monospacedDigit())
                    .frame(minWidth: 18, alignment: .center)

                Button {
                    onQuantityChange(deckCard.quantity + 1)
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(isHighlighted ? Color.yellow.opacity(0.25) : nil)
        .animation(.easeInOut(duration: 0.3), value: isHighlighted)
    }
}

// MARK: - Recommendation card detail sheet

private struct RecommendationCardDetailSheet: View {
    let rec: CardRecommendation
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    AsyncImage(url: URL(string: rec.card.largeImageURL ?? rec.card.imageURL)) { phase in
                        if case .success(let img) = phase {
                            img.resizable().aspectRatio(contentMode: .fit)
                        } else {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.quaternary)
                                .aspectRatio(2/3, contentMode: .fit)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 24)
                    .shadow(color: .black.opacity(0.18), radius: 12, y: 6)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(rec.card.name)
                                .font(.title3.bold())
                            Spacer()
                            Text(rec.card.supertype)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        Text("\(rec.card.setName) · #\(rec.card.number)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Divider().padding(.vertical, 4)

                        Label {
                            Text(rec.reason)
                                .font(.subheadline)
                        } icon: {
                            Image(systemName: rec.scoreSystemImage)
                        }
                        .foregroundStyle(.secondary)

                        Label(rec.scoreLabel, systemImage: rec.scoreSystemImage)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(.fill.tertiary, in: Capsule())
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
                .padding(.top, 16)
            }
            .navigationTitle(rec.card.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
