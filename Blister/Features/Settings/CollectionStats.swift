import Foundation

/// A summary of the collection for the Settings stats section (spec §6.6): owned/wishlist counts and
/// money totals. Aggregation is a pure function over `[Car]` so it is unit tested independently of the
/// view. Money is summed as `Decimal` — never `Double` — and `nil` prices/values are skipped.
struct CollectionStats: Equatable {
    var ownedCount: Int = 0
    var wishlistCount: Int = 0
    var totalSpentINR: Decimal = 0
    var totalEstimatedValueINR: Decimal = 0

    static func compute(from cars: [Car]) -> CollectionStats {
        var stats = CollectionStats()
        for car in cars {
            switch car.status {
            case .owned:  stats.ownedCount += 1
            case .wanted: stats.wishlistCount += 1
            }
            if let price = car.purchasePriceINR {
                stats.totalSpentINR += price
            }
            if let value = car.estimatedValueINR {
                stats.totalEstimatedValueINR += value
            }
        }
        return stats
    }
}
