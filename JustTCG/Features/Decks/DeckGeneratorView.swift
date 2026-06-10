import SwiftUI
import SwiftData

struct DeckGeneratorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var messages: [GeneratorMessage] = []
    @State private var draft = ""
    @State private var isGenerating = false
    @State private var hasGeneratedFirst = false
    @State private var importDeckList: String? = nil
    @State private var importName = ""
    @State private var showImportSheet = false
    @State private var isImporting = false
    @State private var importWarning: String? = nil
    @State private var engineBox: AnyObject? = nil

    private let sourceStrategy = DeckSourceStrategy.live

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                conversationList
                Divider()
                inputBar
            }
            .navigationTitle("Deck Generator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !messages.isEmpty {
                        Button("Start over") { reset() }
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showImportSheet) {
                importSheet
            }
        }
        .task {
            if #available(iOS 26, *), engineBox == nil {
                engineBox = DeckGeneratorEngine()
            }
        }
    }

    // MARK: - Conversation list

    private var conversationList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if messages.isEmpty {
                    emptyPrompt
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { msg in
                            messageView(msg).id(msg.id)
                        }
                        if isGenerating {
                            HStack {
                                ProgressView()
                                    .padding(10)
                                    .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 14))
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
            .onChange(of: messages.count) {
                withAnimation { proxy.scrollTo(messages.last?.id, anchor: .bottom) }
            }
        }
    }

    @ViewBuilder
    private func messageView(_ msg: GeneratorMessage) -> some View {
        if msg.role == .user {
            HStack {
                Spacer(minLength: 60)
                Text(msg.text)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(explanationText(from: msg.text))
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 14))
                    Spacer(minLength: 60)
                }
                if let list = msg.deckList {
                    DeckListPreviewCard(deckList: list) { deckList in
                        importName = suggestedName(from: deckList)
                        importDeckList = deckList
                        showImportSheet = true
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var emptyPrompt: some View {
        Text("Describe a deck idea and I'll build it.\nFor example: \"Build me a Charizard ex deck\" or \"Something fast with Miraidon ex\".")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Describe the deck you want…", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .disabled(isGenerating)
            Button { send() } label: {
                Image(systemName: "arrow.up.circle.fill").font(.title2)
            }
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || isGenerating)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Import sheet

    private var importSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Deck name", text: $importName)
                }
                if let warning = importWarning {
                    Section {
                        Label(warning, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Name Your Deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { showImportSheet = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create Deck") { performImport() }
                        .disabled(isImporting || importName.trimmingCharacters(in: .whitespaces).isEmpty)
                        .overlay {
                            if isImporting { ProgressView().scaleEffect(0.8) }
                        }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Actions

    private func send() {
        let prompt = draft.trimmingCharacters(in: .whitespaces)
        guard !prompt.isEmpty else { return }
        messages.append(GeneratorMessage(role: .user, text: prompt, deckList: nil))
        draft = ""
        isGenerating = true

        let catalog = DeckGeneratorCatalog.candidatePokemon(for: prompt, in: context)
        let archetypeCandidates = DeckGeneratorCatalog.archetypeCandidates(for: prompt, in: context)
        let aiAvailable: Bool = {
            if #available(iOS 26, *) { return engineBox is DeckGeneratorEngine }
            return false
        }()

        Task {
            do {
                if !hasGeneratedFirst {
                    // First send: try a real tournament deck before anything else.
                    let checkLegality: (LimitlessDeckList) -> DeckLegalityResult = { deck in
                        DeckLegalityChecker.check(deck, in: context)
                    }
                    if let hit = await sourceStrategy.lookup(candidates: archetypeCandidates, checkLegality: checkLegality) {
                        let text: String
                        if hit.hasUnknownCards {
                            text = "Found a tournament deck: \(hit.label), but it may not be built for Standard play. Please validate yourself."
                        } else {
                            text = "Found a tournament deck: \(hit.label)."
                        }
                        messages.append(GeneratorMessage(
                            role: .assistant,
                            text: text,
                            deckList: hit.deckList
                        ))
                        hasGeneratedFirst = true
                        isGenerating = false
                        return
                    }
                    // Strategy miss. If Apple Intelligence is unavailable on this
                    // device, surface a clear "no tournament results" message
                    // rather than the generic AI-unavailable copy.
                    guard aiAvailable else {
                        messages.append(GeneratorMessage(
                            role: .assistant,
                            text: "No tournament deck found for that. Try a specific archetype like \"Charizard ex\", \"Miraidon ex\", or \"Gardevoir ex\".",
                            deckList: nil
                        ))
                        isGenerating = false
                        return
                    }
                    if #available(iOS 26, *), let engine = engineBox as? DeckGeneratorEngine {
                        var lastPhase: DeckGeneratorResponse? = nil
                        for try await phase in engine.generate(prompt: prompt, pokemonCatalog: catalog) {
                            if !phase.isIntermediate {
                                lastPhase = phase
                            }
                        }
                        // If Phase 3 produced no parseable deck (e.g. the model
                        // returned only section headers), surface a clean
                        // "couldn't build a deck" message instead of rendering
                        // the raw output as if it were content.
                        if let phase = lastPhase, phase.deckList != nil {
                            messages.append(GeneratorMessage(role: .assistant, text: phase.message, deckList: phase.deckList))
                        } else {
                            messages.append(GeneratorMessage(
                                role: .assistant,
                                text: "I couldn't build a complete deck for that prompt. Try a more specific archetype like \"Charizard ex\", \"Miraidon ex\", or \"Gardevoir ex\".",
                                deckList: nil
                            ))
                        }
                        hasGeneratedFirst = true
                    }
                } else {
                    // Refine path — requires the AI engine.
                    guard aiAvailable else {
                        messages.append(GeneratorMessage(
                            role: .assistant,
                            text: "Refining decks requires Apple Intelligence (iPhone 16 or later running iOS 26 or later). Tap Start over to look up a different tournament deck.",
                            deckList: nil
                        ))
                        isGenerating = false
                        return
                    }
                    if #available(iOS 26, *), let engine = engineBox as? DeckGeneratorEngine {
                        let response = try await engine.refine(prompt: prompt)
                        messages.append(GeneratorMessage(role: .assistant, text: response.message, deckList: response.deckList))
                    }
                }
            } catch {
                messages.append(GeneratorMessage(role: .assistant, text: "Something went wrong. Please try again.", deckList: nil))
            }
            isGenerating = false
        }
    }

    private func reset() {
        messages.removeAll()
        hasGeneratedFirst = false
        if #available(iOS 26, *), let engine = engineBox as? DeckGeneratorEngine {
            engine.reset()
        }
    }

    private func performImport() {
        guard let deckList = importDeckList else { return }
        isImporting = true
        let name = importName.trimmingCharacters(in: .whitespaces)

        let entries = DeckListParser.parse(deckList)
        let matches = DeckImportLookup().resolve(entries, in: context)
        let unresolved = matches.filter { !$0.isMatched }

        if !unresolved.isEmpty {
            let names = unresolved.prefix(3).map { $0.entry.name }.joined(separator: ", ")
            importWarning = "Could not match: \(names)\(unresolved.count > 3 ? " and \(unresolved.count - 3) more" : "")"
        }

        let deck = DeckRepository(modelContext: context).createDeck(name: name.isEmpty ? "Generated Deck" : name)
        for match in matches where match.isMatched {
            let entry = match.entry
            DeckRepository(modelContext: context).addCard(
                cardId: match.cardId!,
                to: deck,
                isBasicEnergy: entry.name.contains("Energy"),
                cardName: entry.name
            )
        }

        isImporting = false
        showImportSheet = false
        dismiss()
    }

    // MARK: - Helpers

    private func explanationText(from message: String) -> String {
        let lines = message.components(separatedBy: "\n")
        let nonDeckLines = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Drop card lines (start with a number)
            let parts = trimmed.components(separatedBy: " ")
            if parts.count >= 2, Int(parts[0]) != nil { return false }
            // Drop section headers and total line
            let lower = trimmed.lowercased()
            if lower.hasPrefix("pokémon:") || lower.hasPrefix("pokemon:")
                || lower.hasPrefix("trainer:") || lower.hasPrefix("energy:")
                || lower.hasPrefix("total cards:") { return false }
            return true
        }
        return nonDeckLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func suggestedName(from deckList: String) -> String {
        let firstLine = deckList.components(separatedBy: "\n").first {
            let parts = $0.components(separatedBy: " ")
            return parts.count >= 2 && Int(parts[0]) != nil
        }
        guard let line = firstLine else { return "Generated Deck" }
        let tokens = line.components(separatedBy: " ").dropFirst()
        let name = tokens.prefix(while: { !$0.allSatisfy({ $0.isUppercase || $0.isNumber }) }).joined(separator: " ")
        return name.isEmpty ? "Generated Deck" : "\(name) Deck"
    }
}

// MARK: - Message model

private struct GeneratorMessage: Identifiable {
    let id = UUID()
    let role: Role
    let text: String
    let deckList: String?
    enum Role { case user, assistant }
}
