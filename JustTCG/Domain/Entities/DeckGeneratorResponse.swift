import Foundation

struct DeckGeneratorResponse {
    let message: String
    let deckList: String?
    let isFollowUpQuestion: Bool
}

enum DeckListExtractor {
    static func extract(from text: String) -> String? {
        let lines = text.components(separatedBy: "\n")
        let deckLines = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return false }
            let parts = trimmed.components(separatedBy: " ")
            guard parts.count >= 2, let count = Int(parts[0]), count > 0 else { return false }
            return true
        }
        guard deckLines.count >= 10 else { return nil }
        return deckLines.joined(separator: "\n")
    }
}
