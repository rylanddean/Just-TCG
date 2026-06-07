import Foundation

struct DeckImportEntry {
    let quantity: Int
    let name: String
    let setCode: String
    let number: String
}

enum DeckListParser {
    // Parses PTCGL-format clipboard text into DeckImportEntry values.
    // Section headers (Pokémon: N, Trainer: N, Energy: N) and the Total Cards
    // footer are silently skipped, as are blank lines and malformed lines.
    static func parse(_ text: String) -> [DeckImportEntry] {
        text.components(separatedBy: .newlines).compactMap { parseLine($0) }
    }

    private static func parseLine(_ line: String) -> DeckImportEntry? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        let lower = trimmed.lowercased()
        if lower.hasPrefix("pokémon:") || lower.hasPrefix("pokemon:")
            || lower.hasPrefix("trainer:") || lower.hasPrefix("energy:")
            || lower.hasPrefix("total cards:") {
            return nil
        }

        let tokens = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard tokens.count >= 4,
              let quantity = Int(tokens[0]), quantity > 0
        else { return nil }

        let number  = tokens[tokens.count - 1]
        let setCode = tokens[tokens.count - 2]
        let name    = tokens[1 ..< tokens.count - 2].joined(separator: " ")

        return DeckImportEntry(quantity: quantity, name: name, setCode: setCode, number: number)
    }
}
