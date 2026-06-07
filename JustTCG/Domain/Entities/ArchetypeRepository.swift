import Foundation

struct ArchetypeRepository {
    static let shared = ArchetypeRepository()

    let all: [Archetype]

    private init() {
        guard
            let url = Bundle.main.url(forResource: "archetypes", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode([Archetype].self, from: data)
        else {
            all = []
            return
        }
        all = decoded.sorted { $0.name < $1.name }
    }

    func search(query: String) -> [Archetype] {
        guard !query.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }
}
