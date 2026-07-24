import Foundation

enum Condition: String, Codable, CaseIterable, Identifiable {
    case mintOnCard, openedCard, loose, damaged

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mintOnCard: return String(localized: "Mint on Card")
        case .openedCard: return String(localized: "Opened Card")
        case .loose:      return String(localized: "Loose")
        case .damaged:    return String(localized: "Damaged")
        }
    }
}
