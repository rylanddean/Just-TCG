import Foundation
import Observation

@Observable
final class PlayerDetailViewModel {

    private(set) var profile: LimitlessPlayerProfile? = nil
    private(set) var isLoading = false
    private(set) var error: String? = nil

    private let playerID: String
    private let client = LimitlessTCGClient()

    init(playerID: String) {
        self.playerID = playerID
    }

    func load() async {
        guard profile == nil else { return }
        await fetch()
    }

    func refresh() async {
        await fetch()
    }

    private func fetch() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            profile = try await client.fetchPlayerProfile(id: playerID)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
