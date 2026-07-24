import Testing
import Foundation
@testable import Blister

/// Ranking + lookup for the bundled reference catalog (spec §v2.3). Deterministic tests use an
/// in-memory `CatalogStore(entries:)`; one smoke test asserts the shipped `catalog.json` loads.
struct CatalogStoreTests {

    private func store() -> CatalogStore {
        CatalogStore(entries: [
            CatalogEntry(id: "1", castingName: "Nissan Skyline GT-R R34", brand: .hotWheels,
                         series: "Car Culture", priceINR: 1200),
            CatalogEntry(id: "2", castingName: "Nissan Skyline GT-R R32", brand: .hotWheels,
                         series: "Japan Historics", priceINR: 1100),
            CatalogEntry(id: "3", castingName: "Toyota AE86 Corolla", brand: .hotWheels,
                         series: "Car Culture", priceINR: 950),
            CatalogEntry(id: "4", castingName: "Mitsubishi Pajero Sport", brand: .miniGT,
                         series: "Mini GT", priceINR: 1400)
        ])
    }

    @Test func emptyQueryReturnsNoMatches() {
        #expect(store().search("").isEmpty)
        #expect(store().search("   ").isEmpty)
    }

    @Test func exactCastingRanksFirst() {
        let results = store().search("Toyota AE86 Corolla")
        #expect(results.first?.id == "3")
    }

    @Test func prefixTokenMatches() {
        // "pajero" is a prefix of a casting token; should surface the Pajero entry.
        let results = store().search("pajero")
        #expect(results.contains { $0.id == "4" })
    }

    @Test func tokenSubsetMatchesAcrossCastingAndSeries() {
        // Two Skylines share these tokens; both should match, none of the others.
        let results = store().search("nissan skyline")
        let ids = Set(results.map(\.id))
        #expect(ids == ["1", "2"])
    }

    @Test func limitIsRespected() {
        #expect(store().search("nissan", limit: 1).count == 1)
    }

    @Test func matchingCastingIsCaseAndDiacriticInsensitive() {
        let entry = store().entry(matchingCasting: "toyota ae86 corolla")
        #expect(entry?.id == "3")
    }

    @Test func matchingCastingReturnsNilForUnknown() {
        #expect(store().entry(matchingCasting: "Lamborghini Countach") == nil)
    }

    @Test func referencePriceConvertsToDecimal() {
        let entry = CatalogEntry(id: "x", castingName: "Test", brand: .other, series: nil, priceINR: 1400)
        #expect(entry.referencePriceINR == Decimal(1400))
        #expect(CatalogEntry(id: "y", castingName: "T", brand: .other, series: nil, priceINR: nil)
            .referencePriceINR == nil)
    }

    @Test func bundledCatalogLoadsAndDecodes() {
        // The shipped catalog.json must load from the app bundle with at least a handful of entries.
        let shared = CatalogStore.shared
        #expect(shared.entries.count >= 20)
        #expect(shared.entries.allSatisfy { !$0.castingName.isEmpty })
    }
}
