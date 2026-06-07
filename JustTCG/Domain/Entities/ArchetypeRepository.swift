import Foundation

struct ArchetypeRepository {
    static let shared = ArchetypeRepository()

    /// All archetypes sorted alphabetically — used for type-ahead search.
    let all: [Archetype]

    /// Archetypes in the order they appear in `archetypes.json`, i.e. current
    /// meta prevalence order (most popular first). Used by the Quick Pick picker.
    let metaOrdered: [Archetype]

    private init() {
        guard
            let url = Bundle.main.url(forResource: "archetypes", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode([Archetype].self, from: data)
        else {
            all = []
            metaOrdered = []
            return
        }
        metaOrdered = decoded
        all = decoded.sorted { $0.name < $1.name }
    }

    func search(query: String) -> [Archetype] {
        guard !query.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }
}
