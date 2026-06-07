import Foundation

// Public interface for all external data fetching.
// Card data comes from api.pokemontcg.io; tournament data from limitlesstcg.com HTML.
struct LimitlessTCGClient {

    private let cardClient: PokemonTCGAPIClient
    private let session: URLSession
    private static let limitlessBase = URL(string: "https://limitlesstcg.com")!

    init(session: URLSession = .shared, pokemonTCGApiKey: String? = nil) {
        self.cardClient = PokemonTCGAPIClient(session: session, apiKey: pokemonTCGApiKey)
        self.session = session
    }

    // MARK: - Cards

    func fetchStandardCards(page: Int) async throws -> [LimitlessCard] {
        try await cardClient.fetchStandardCards(page: page).data.map { $0.toLimitlessCard() }
    }

    func fetchStandardCardPage(page: Int) async throws -> PTCGPageResult {
        try await cardClient.fetchStandardCards(page: page)
    }

    func fetchCard(id: String) async throws -> LimitlessCard {
        try await cardClient.fetchCard(id: id)
    }

    // MARK: - Tournaments

    func fetchRecentTournaments(limit: Int = 50) async throws -> [LimitlessTournament] {
        let html = try await fetchHTML(from: Self.limitlessBase.appendingPathComponent("tournaments"))
        let all = LimitlessHTMLParser.parseTournaments(from: html)
        return Array(all.prefix(limit))
    }

    func fetchTournamentDetail(id: String) async throws -> LimitlessTournamentDetail {
        let url = Self.limitlessBase.appendingPathComponent("tournaments").appendingPathComponent(id)
        let html = try await fetchHTML(from: url)
        let placements = LimitlessHTMLParser.parsePlacements(from: html)
        return LimitlessTournamentDetail(id: id, placements: placements)
    }

    func fetchPlayerProfile(id: String) async throws -> LimitlessPlayerProfile {
        let url = Self.limitlessBase.appendingPathComponent("players").appendingPathComponent(id)
        let html = try await fetchHTML(from: url)
        guard let profile = LimitlessHTMLParser.parsePlayerProfile(id: id, from: html) else {
            throw LimitlessClientError.invalidResponse(200)
        }
        return profile
    }

    func fetchDeckList(listId: String) async throws -> LimitlessDeckList {
        let url = Self.limitlessBase
            .appendingPathComponent("decks")
            .appendingPathComponent("list")
            .appendingPathComponent(listId)
        let html = try await fetchHTML(from: url)
        return LimitlessHTMLParser.parseDeckList(listId: listId, from: html)
    }

    // MARK: - Private

    private func fetchHTML(from url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.setValue("text/html", forHTTPHeaderField: "Accept")
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await withRetry {
            try await self.session.data(for: request)
        }
        guard let http = response as? HTTPURLResponse else {
            throw LimitlessClientError.invalidResponse(0)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw LimitlessClientError.invalidResponse(http.statusCode)
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
}

// MARK: - Retry (shared, not tied to a specific client instance)

func withRetry<T>(maxAttempts: Int = 3, operation: () async throws -> T) async throws -> T {
    var lastError: Error = LimitlessClientError.offline
    for attempt in 0..<maxAttempts {
        do {
            return try await operation()
        } catch {
            lastError = error
            if attempt < maxAttempts - 1 {
                let delay = pow(2.0, Double(attempt)) // 1s, 2s
                try await Task.sleep(for: .seconds(delay))
            }
        }
    }
    throw LimitlessClientError.retryExhausted(underlying: lastError)
}
