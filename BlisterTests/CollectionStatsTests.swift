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
