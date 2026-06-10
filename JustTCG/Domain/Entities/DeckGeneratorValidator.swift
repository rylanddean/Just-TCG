import Foundation

struct DeckGeneratorViolation: Identifiable {
    enum Kind {
        case wrongTotal(actual: Int)
        case exceeds4Copies(name: String, total: Int)
    }
    let id = UUID()
    let kind: Kind

    var description: String {
        switch kind {
        case .wrongTotal(let actual):
            return "Deck has \(actual) cards (need exactly 60)"
        case .exceeds4Copies(let name, let total):
            return "\(name): \(total) copies (max 4)"
        }
    }
}

enum DeckGeneratorValidator {
    private static let basicEnergyTypes: Set<String> = [
        "fire", "water", "grass", "lightning", "psychic",
        "darkness", "fighting", "metal", "fairy", "dragon"
    ]

    static func validate(_ deckList: String) -> [DeckGeneratorViolation] {
        let entries = DeckListParser.parse(deckList)
        var violations: [DeckGeneratorViolation] = []

        let total = entries.reduce(0) { $0 + $1.quantity }
        if total != 60 {
            violations.append(DeckGeneratorViolation(kind: .wrongTotal(actual: total)))
        }

        // Group by name (case-insensitive) to catch same-name cards from different sets.
        var countsByName: [String: (display: String, count: Int)] = [:]
        for entry in entries {
            let key = entry.name.lowercased()
            let existing = countsByName[key] ?? (entry.name, 0)
            countsByName[key] = (existing.display, existing.count + entry.quantity)
        }

        for (_, pair) in countsByName where pair.count > 4 {
            guard !isBasicEnergy(name: pair.display) else { continue }
            violations.append(DeckGeneratorViolation(kind: .exceeds4Copies(name: pair.display, total: pair.count)))
        }

        return violations
    }

    private static func isBasicEnergy(name: String) -> Bool {
        let lower = name.lowercased()
        guard lower.hasSuffix("energy") else { return false }
        return basicEnergyTypes.contains(where: { lower.contains($0) })
    }
}
