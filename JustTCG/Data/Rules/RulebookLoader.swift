import Foundation

struct RulebookLoader {
    static func load() -> [RulebookSection] {
        guard
            let url = Bundle.main.url(forResource: "PokemonTCGRules", withExtension: "json"),
            let data = try? Data(contentsOf: url)
        else { return [] }
        return (try? JSONDecoder().decode([RulebookSection].self, from: data)) ?? []
    }

    static func fullText() -> String {
        load()
            .map { "## \($0.title)\n\($0.body)" }
            .joined(separator: "\n\n")
    }
}
