import Testing
@testable import Blister

/// OCR × catalog fusion (v2.2 step 2): ranked specific-casting identification from OCR candidate
/// lines. Deterministic — uses a fixed in-memory `CatalogStore`.
struct CatalogMatcherTests {

    private func catalog() -> CatalogStore {
        CatalogStore(entries: [
            CatalogEntry(id: "r34", castingName: "Nissan Skyline GT-R R34", brand: .hotWheels,
                         series: "Car Culture", priceINR: 1200),
            CatalogEntry(id: "r32", castingName: "Nissan Skyline GT-R R32", brand: .hotWheels,
                         series: "Japan Historics", priceINR: 1100),
            CatalogEntry(id: "ae86", castingName: "Toyota AE86 Corolla", brand: .hotWheels,
                         series: "Car Culture", priceINR: 950)
        ])
    }

    @Test func identifiesEntryFromOCRLine() {
        let matches = CatalogMatcher.matches(for: ["NISSAN SKYLINE GT-R R34", "collector no 123"],
                                             in: catalog())
        #expect(matches.first?.id == "r34")
    }

    @Test func earlierOCRLineOutranksLaterLine() {
        // AE86 appears on the first (most prominent) line, R32 on a later line: AE86 should win.
        let matches = CatalogMatcher.matches(for: ["Toyota AE86 Corolla", "Nissan Skyline R32"],
                                             in: catalog())
        #expect(matches.first?.id == "ae86")
    }

    @Test func deduplicatesEntryAcrossLines() {
        let matches = CatalogMatcher.matches(for: ["Skyline", "Nissan Skyline GT-R R34"],
                                             in: catalog())
        #expect(matches.filter { $0.id == "r34" }.count == 1)
    }

    @Test func noMatchReturnsEmpty() {
        #expect(CatalogMatcher.matches(for: ["Lamborghini Countach", "1988"], in: catalog()).isEmpty)
        #expect(CatalogMatcher.matches(for: [], in: catalog()).isEmpty)
    }

    @Test func respectsLimit() {
        let matches = CatalogMatcher.matches(for: ["Nissan Skyline"], in: catalog(), limit: 1)
        #expect(matches.count == 1)
    }
}
