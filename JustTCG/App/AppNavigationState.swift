import Foundation
import Observation

@Observable
final class AppNavigationState {
    var selectedTab: Int = 0
    var tournamentsArchetypeFilter: String? = nil

    static let tabCompetition = 3
    static let tabPrep = 4
}
