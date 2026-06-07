import SwiftData
import Foundation

enum CardSortOrder: String, CaseIterable, Identifiable, Equatable {
    case expansion
    case name
    case hp
    case attackDamage
    case regulationMark

    var id: String { rawValue }

    var menuLabel: String {
        switch self {
        case .expansion:     return "Expansion (Newest First)"
        case .name:          return "Name (A → Z)"
        case .hp:            return "HP (Highest First)"
        case .attackDamage:  return "Attack Damage (Highest First)"
        case .regulationMark: return "Regulation Mark (Latest First)"
        }
    }

    var sortDescriptors: [SortDescriptor<CachedCard>] {
        switch self {
        case .expansion:
            return [
                SortDescriptor(\.setReleaseDate, order: .reverse),
                SortDescriptor(\.numberSortKey),
            ]
        case .name:
            return [SortDescriptor(\.name)]
        case .hp:
            return [
                SortDescriptor(\.hp, order: .reverse),
                SortDescriptor(\.name),
            ]
        case .attackDamage:
            return [
                SortDescriptor(\.maxDamage, order: .reverse),
                SortDescriptor(\.name),
            ]
        case .regulationMark:
            return [
                SortDescriptor(\.regulationMark, order: .reverse),
                SortDescriptor(\.numberSortKey),
            ]
        }
    }
}
