import Foundation

struct MetaDeckRepository {
    static let shared = MetaDeckRepository()
    let all: [String]

    private init() {
        guard
            let url = Bundle.main.url(forResource: "metaDecks", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode([String].self, from: data)
        else { all = []; return }
        all = decoded
    }
}
