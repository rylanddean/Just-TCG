import Foundation

// Fetches Standard-legal card data from api.pokemontcg.io/v2.
// Internally used by LimitlessTCGClient — not part of the public interface.
struct PokemonTCGAPIClient {

    private let session: URLSession
    private let apiKey: String?
    private static let base = URL(string: "https://api.pokemontcg.io/v2")!

    init(session: URLSession = .shared, apiKey: String? = nil) {
        self.session = session
        self.apiKey = apiKey
    }

    // Returns all Standard-legal cards for the given page (1-indexed).
    // Page size is fixed at 250. Caller loops until response.hasMore == false.
    func fetchStandardCards(page: Int) async throws -> PTCGPageResult {
        var components = URLComponents(url: Self.base.appendingPathComponent("cards"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: "set.legalities.standard:legal"),
            URLQueryItem(name: "pageSize", value: "250"),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "orderBy", value: "set.releaseDate,number"),
        ]
        let url = components.url!
        return try await withRetry { try await self.decode(PTCGPageResult.self, from: url) }
    }

    func fetchCard(id: String) async throws -> LimitlessCard {
        let url = Self.base.appendingPathComponent("cards").appendingPathComponent(id)
        let wrapper = try await withRetry { try await self.decode(PTCGSingleCardResult.self, from: url) }
        return wrapper.data.toLimitlessCard()
    }

    // MARK: - Networking helpers

    private func decode<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let key = apiKey {
            request.setValue(key, forHTTPHeaderField: "X-Api-Key")
        }

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw LimitlessClientError.invalidResponse(0)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw LimitlessClientError.invalidResponse(http.statusCode)
        }

        do {
            return try JSONDecoder().decode(type, from: data)
        } catch let err as DecodingError {
            throw LimitlessClientError.decodingFailed(err.localizedDescription)
        }
    }
}

// MARK: - Codable response types

struct PTCGPageResult: Decodable {
    let data: [PTCGCard]
    let page: Int
    let pageSize: Int
    let count: Int
    let totalCount: Int

    var hasMore: Bool { page * pageSize < totalCount }
}

private struct PTCGSingleCardResult: Decodable {
    let data: PTCGCard
}

struct PTCGCard: Decodable {
    let id: String
    let name: String
    let supertype: String?
    let subtypes: [String]?
    let hp: String?
    let types: [String]?
    let set: PTCGSet
    let number: String
    let legalities: PTCGLegalities?
    let images: PTCGImages
    let rules: [String]?
    let attacks: [PTCGAttack]?
    let abilities: [PTCGAbility]?

    func toLimitlessCard() -> LimitlessCard {
        let abilityLines: [String] = (abilities ?? []).map { ability in
            let header = "[\(ability.type ?? "Ability")] \(ability.name)"
            guard let text = ability.text, !text.isEmpty else { return header }
            return "\(header)\n\(text)"
        }
        let attackLines: [String] = (attacks ?? []).map { attack in
            var header = attack.name
            if let dmg = attack.damage, !dmg.isEmpty { header += " · \(dmg)" }
            guard let text = attack.text, !text.isEmpty else { return header }
            return "\(header)\n\(text)"
        }
        let allText = abilityLines + attackLines + (rules ?? [])

        return LimitlessCard(
            id: id,
            name: name,
            supertype: supertype ?? "",
            setCode: set.ptcgoCode ?? set.id.uppercased(),
            setName: set.name,
            number: number,
            types: types ?? [],
            subtypes: subtypes ?? [],
            hp: hp.flatMap(Int.init),
            // nil → assume legal (cards come from a Standard-legal set query;
            //       only explicit "Banned" / "Illegal" values should mark false)
            isStandardLegal: legalities.flatMap { $0.standard }
                .map { $0.caseInsensitiveCompare("Legal") == .orderedSame } ?? true,
            imageURL: images.small,
            largeImageURL: images.large,
            rulesText: allText
        )
    }
}

struct PTCGAttack: Decodable {
    let name: String
    let cost: [String]?
    let damage: String?
    let text: String?
}

struct PTCGAbility: Decodable {
    let name: String
    let text: String?
    let type: String?
}

struct PTCGSet: Decodable {
    let id: String
    let name: String
    let ptcgoCode: String?
    let releaseDate: String?
}

struct PTCGLegalities: Decodable {
    let unlimited: String?
    let standard: String?
    let expanded: String?
}

struct PTCGImages: Decodable {
    let small: String
    let large: String?
}
