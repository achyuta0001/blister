import Foundation

enum HuntStatus: String, Codable, CaseIterable, Identifiable {
    case none, treasureHunt, superTreasureHunt

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none:              return String(localized: "None")
        case .treasureHunt:      return String(localized: "Treasure Hunt")
        case .superTreasureHunt: return String(localized: "Super Treasure Hunt")
        }
    }

    /// Short badge label for grid cards. `nil` when there is nothing to flag.
    var badge: String? {
        switch self {
        case .none:              return nil
        case .treasureHunt:      return "TH"
        case .superTreasureHunt: return "$TH"
        }
    }
}
