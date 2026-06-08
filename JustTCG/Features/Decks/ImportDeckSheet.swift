import SwiftUI
import SwiftData
import UIKit

struct ImportDeckSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var deckName = "Imported Deck"
    @State private var matches: [DeckImportMatch] = []
    @State private var isLoading = true
    @State private var swapEntry: DeckImportMatch? = nil

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
                    }
                }
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
        HStack(spacing: 12) {
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
        let text = UIPasteboard.general.string ?? ""
        let entries = DeckListParser.parse(text)
        matches = DeckImportLookup().resolve(entries, in: context)
        isLoading = false
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
        dismiss()
    }
}
