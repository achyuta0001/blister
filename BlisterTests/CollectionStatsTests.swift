import Testing
import Foundation
@testable import Blister

/// Collection stats aggregation (spec §6.6): counts by status and Decimal money sums with nil handling.
struct CollectionStatsTests {

    @Test func countsAndSums() {
        let cars = [
            Car(castingName: "a", status: .owned,
                purchasePriceINR: Decimal(string: "1200"), estimatedValueINR: Decimal(string: "3000")),
            Car(castingName: "b", status: .owned,
                purchasePriceINR: Decimal(string: "800.50"), estimatedValueINR: Decimal(string: "1500")),
            Car(castingName: "c", status: .wanted,
                purchasePriceINR: nil, estimatedValueINR: Decimal(string: "500"))
        ]

        let stats = CollectionStats.compute(from: cars)

        #expect(stats.ownedCount == 2)
        #expect(stats.wishlistCount == 1)
        // nil price on the wanted car is skipped, not treated as zero-crash.
        #expect(stats.totalSpentINR == Decimal(string: "2000.50"))
        #expect(stats.totalEstimatedValueINR == Decimal(string: "5000"))
    }

    /// `compute` is deliberately status-blind: it sums `purchasePriceINR` on every car it is handed.
    /// So a wishlist car still carrying a price *does* inflate "total spent" with money that was never
    /// spent — which is why the guard has to sit on the write side. This pins both halves: the sum
    /// counts a stale price, and clearing it the way a save into the wishlist now does takes it back
    /// out. Until the edit form was fixed it could produce exactly this car.
    @Test func wantedCarWithAStalePriceStillCountsAsSpend() {
        let stale = Car(castingName: "'67 Camaro", status: .wanted,
                        purchasePriceINR: Decimal(string: "1200"),
                        purchaseLocation: "Hamleys Phoenix Mall")

        #expect(CollectionStats.compute(from: [stale]).totalSpentINR == Decimal(string: "1200"))

        CarPurchaseFields.cleared.apply(to: stale)

        let stats = CollectionStats.compute(from: [stale])
        #expect(stats.totalSpentINR == 0)
        #expect(stats.wishlistCount == 1)
        #expect(stats.ownedCount == 0)
    }

    @Test func emptyCollectionIsAllZero() {
        let stats = CollectionStats.compute(from: [])
        #expect(stats == CollectionStats())
        #expect(stats.totalSpentINR == 0)
    }

    @Test func allNilMoneySumsToZero() {
        let cars = [
            Car(castingName: "a", status: .owned, purchasePriceINR: nil, estimatedValueINR: nil),
            Car(castingName: "b", status: .owned, purchasePriceINR: nil, estimatedValueINR: nil)
        ]
        let stats = CollectionStats.compute(from: cars)
        #expect(stats.ownedCount == 2)
        #expect(stats.totalSpentINR == 0)
        #expect(stats.totalEstimatedValueINR == 0)
    }
}
