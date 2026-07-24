import Testing
import Foundation
@testable import Blister

/// Data-integrity checks for the SHIPPED bundled catalog (`CatalogStore.shared.entries`, spec §v2.3).
/// A bad edit to `catalog.json` — dropped entries, duplicate ids, blank names, missing/bad prices —
/// must fail this suite. Deterministic and pure: reads the read-only catalog only.
struct CatalogDataTests {

    /// The shipped catalog, loaded once from the app bundle.
    private var entries: [CatalogEntry] { CatalogStore.shared.entries }

    @Test func catalogHasExpectedMinimumSize() {
        // Currently 114 entries; guard against accidental truncation.
        #expect(entries.count >= 100)
    }

    @Test func allIDsAreUnique() {
        let ids = Set(entries.map(\.id))
        #expect(ids.count == entries.count)
    }

    @Test func everyCastingNameIsNonEmpty() {
        #expect(entries.allSatisfy {
            !$0.castingName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        })
    }

    @Test func everyEntryHasPositivePrice() {
        #expect(entries.allSatisfy { ($0.priceINR ?? 0) > 0 })
    }

    @Test func referencePriceMirrorsPriceINR() {
        // Non-nil whenever priceINR is set, and value-equal to Decimal(priceINR).
        #expect(entries.allSatisfy { entry in
            entry.priceINR == nil ? entry.referencePriceINR == nil
                                  : entry.referencePriceINR != nil
        })
        // Sample: pick an entry with a price and confirm the exact conversion.
        let sample = entries.first { $0.priceINR != nil }
        #expect(sample != nil)
        if let sample, let price = sample.priceINR {
            #expect(sample.referencePriceINR == Decimal(price))
        }
    }
}
