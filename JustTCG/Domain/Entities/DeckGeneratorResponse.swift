import Foundation

struct DeckGeneratorResponse {
    let message: String
    let deckList: String?
    let isFollowUpQuestion: Bool
    var isIntermediate: Bool = false
}

enum DeckListExtractor {
    static func extract(from text: String) -> String? {
        extractGroupedBlock(from: text) ?? extractRawLines(from: text)
    }

    // Extracts the full "Pokémon: N ... Total Cards: 60" block when the model
    // outputs the structured grouped format.
    private static func extractGroupedBlock(from text: String) -> String? {
        let lines = text.components(separatedBy: "\n")
        guard let startIdx = lines.firstIndex(where: {
            let lower = $0.trimmingCharacters(in: .whitespaces).lowercased()
            return lower.hasPrefix("pokémon:") || lower.hasPrefix("pokemon:")
        }),
        let endIdx = lines.firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces).lowercased().hasPrefix("total cards:")
        }),
        endIdx > startIdx
        else { return nil }

        let block = lines[startIdx...endIdx]
        let total = block.compactMap { line -> Int? in
            let parts = line.trimmingCharacters(in: .whitespaces).components(separatedBy: " ")
            guard parts.count >= 3, let n = Int(parts[0]) else { return nil }
            return n
        }.reduce(0, +)
        guard total >= 55 && total <= 65 else { return nil }
        return block.joined(separator: "\n")
    }

    // Fallback: extract bare card lines when section headers are absent.
    private static func extractRawLines(from text: String) -> String? {
        let lines = text.components(separatedBy: "\n")
        let deckLines = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return false }
            let parts = trimmed.components(separatedBy: " ")
            guard parts.count >= 3, let count = Int(parts[0]), count >= 1, count <= 60 else { return false }
            guard !trimmed.lowercased().hasPrefix("total") else { return false }
            return true
        }
        guard deckLines.count >= 20 else { return nil }
        let total = deckLines.compactMap { Int($0.components(separatedBy: " ")[0]) }.reduce(0, +)
        guard total >= 55 && total <= 65 else { return nil }
        return deckLines.joined(separator: "\n")
    }
}
