import Foundation

struct RulebookSection: Codable, Identifiable {
    var id: String { title }
    let title: String
    let body: String
}
