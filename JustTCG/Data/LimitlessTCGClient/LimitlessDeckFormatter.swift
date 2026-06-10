import Foundation

/// Converts a ``LimitlessDeckList`` into the standard PTCGL export text format:
///
///     Pokémon: N
///     qty name setCode number
///     ...
///
///     Trainer: N
///     qty name setCode number
///     ...
///
///     Energy: N
///     qty name setCode number
///     ...
///
///     Total Cards: 60
///
/// Section membership is determined by ``LimitlessDeckEntry.supertype``,
/// which the HTML parser populates from the deck list page's section headers.
enum LimitlessDeckFormatter {

    static func toPTCGL(_ deckList: LimitlessDeckList) -> String {
        let pokemon  = deckList.entries.filter { $0.supertype == "Pokémon" }
        let trainers = deckList.entries.filter { $0.supertype == "Trainer" }
        let energy   = deckList.entries.filter { $0.supertype == "Energy"  }

        var lines: [String] = []

        if !pokemon.isEmpty {
            let count = pokemon.reduce(0) { $0 + $1.quantity }
            lines.append("Pokémon: \(count)")
            for e in pokemon { lines.append("\(e.quantity) \(e.name) \(e.setCode) \(e.number)") }
            lines.append("")
        }

        if !trainers.isEmpty {
            let count = trainers.reduce(0) { $0 + $1.quantity }
            lines.append("Trainer: \(count)")
            for e in trainers { lines.append("\(e.quantity) \(e.name) \(e.setCode) \(e.number)") }
            lines.append("")
        }

        if !energy.isEmpty {
            let count = energy.reduce(0) { $0 + $1.quantity }
            lines.append("Energy: \(count)")
            for e in energy { lines.append("\(e.quantity) \(e.name) \(e.setCode) \(e.number)") }
            lines.append("")
        }

        let total = deckList.entries.reduce(0) { $0 + $1.quantity }
        lines.append("Total Cards: \(total)")

        return lines.joined(separator: "\n")
    }
}
