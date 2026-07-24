import Foundation

/// Whether a car is owned or merely wanted. The wishlist is not a separate entity — it is simply
/// the set of cars with `status == .wanted` (spec §4). Moving a car from wishlist to garage is a
/// single status flip plus optional purchase fields.
enum CollectionStatus: String, Codable, CaseIterable, Identifiable {
    case owned, wanted

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .owned:  return String(localized: "Owned")
        case .wanted: return String(localized: "Wanted")
        }
    }
}
