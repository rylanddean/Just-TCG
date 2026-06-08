import SwiftUI

struct DeckEditLogView: View {
    let deck: Deck

    private var sortedEdits: [DeckEdit] {
        deck.edits.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            Group {
                if sortedEdits.isEmpty {
                    emptyState
                } else {
                    editList
                }
            }
            .navigationTitle("Changelog")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var editList: some View {
        List(sortedEdits) { edit in
            VStack(alignment: .leading, spacing: 2) {
                Text(edit.displayDescription)
                    .font(.subheadline)
                Text(edit.date.editDisplayString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        }
        .listStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("No changes recorded yet.")
                .font(.headline)
            Text("Edits you make will appear here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - DeckEdit helpers

extension DeckEdit {
    var displayDescription: String {
        switch kind {
        case .addCard:
            let name = cardName ?? cardId ?? "Unknown"
            return "Added \(name) ×\(quantityAfter)"
        case .removeCard:
            let name = cardName ?? cardId ?? "Unknown"
            return "Removed \(name)"
        case .setQuantity:
            let name = cardName ?? cardId ?? "Unknown"
            return "Changed \(name) ×\(quantityBefore)→\(quantityAfter)"
        case .rename:
            return "Renamed \"\(nameBefore ?? "")\" → \"\(nameAfter ?? "")\""
        }
    }
}

extension Date {
    var editDisplayString: String {
        if Date.now.timeIntervalSince(self) < 86_400 {
            let f = RelativeDateTimeFormatter()
            f.unitsStyle = .full
            return f.localizedString(for: self, relativeTo: .now)
        } else {
            let f = DateFormatter()
            f.dateStyle = .medium
            f.timeStyle = .none
            return f.string(from: self)
        }
    }
}
