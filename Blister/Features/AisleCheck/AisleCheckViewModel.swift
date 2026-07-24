import Foundation
import Observation
import os

/// Search / verdict state for Aisle Check (spec §6.1). Owned by Agent 4.
///
/// Holds only value state and a reference to the injected ``SearchEngine`` protocol — never SwiftData.
/// The view feeds it the `@Query`-loaded cars via ``verdict(from:)`` so this stays a pure, testable
/// transform. Deliberately coded against the `SearchEngine` protocol, not any concrete engine.
@MainActor
@Observable
final class AisleCheckViewModel {
    /// Live query text, bound to the bottom search field.
    var query: String = ""

    /// The most recently scanned barcode, if any. When set, it takes precedence over `query` because
    /// the user just physically scanned the item in front of them.
    var scannedBarcode: String?

    /// The engine that ranks the collection. Referenced only through the protocol so we are decoupled
    /// from the Search agent's internals.
    let searchEngine: any SearchEngine

    /// Bundled reference catalog, used only to enrich a miss with a "known casting" hint. Read-only.
    let catalog: CatalogStore

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Blister",
        category: "AisleCheck"
    )

    init(searchEngine: any SearchEngine = LiveSearchEngine(),
         catalog: CatalogStore = .shared) {
        self.searchEngine = searchEngine
        self.catalog = catalog
    }

    /// The trimmed casting name to prefill when adding from a miss.
    var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Switch back to typing, discarding any scanned barcode.
    func clearScan() {
        scannedBarcode = nil
    }

    /// Record a scanned barcode. Clears the text query so the barcode drives the verdict.
    func didScan(_ code: String) {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        logger.info("Barcode scanned (hint only): \(trimmed, privacy: .public)")
        query = ""
        scannedBarcode = trimmed
    }

    /// Compute the verdict against the collection. Pure: reads only `query` / `scannedBarcode` and the
    /// injected engine, so it can be unit-tested with a fixed `[Car]` array.
    func verdict(from cars: [Car]) -> AisleVerdict {
        // A live barcode scan wins — the user is holding the exact package.
        if let barcode = scannedBarcode, !barcode.isEmpty {
            let matches = cars
                .filter { $0.barcode == barcode }
                .sorted { $0.dateAdded > $1.dateAdded }
            return matches.isEmpty ? .barcodeMiss(barcode: barcode) : .barcodeHint(matches: matches)
        }

        let trimmed = trimmedQuery
        guard !trimmed.isEmpty else { return .idle }

        let results = searchEngine.search(trimmed, in: cars)
        guard let top = results.first else {
            // Nothing owned or wanted. Offer a catalog hint (exact casting first, else best match).
            let hint = catalog.entry(matchingCasting: trimmed) ?? catalog.search(trimmed, limit: 1).first
            return .notInCollection(query: trimmed, catalogHint: hint)
        }

        // Prefer an owned match: that is the "already in your collection" answer.
        if let ownedTop = results.first(where: { $0.status == .owned }) {
            let sameCasting = ownedCars(cars, matching: ownedTop)
            return .inCollection(primary: ownedTop, ownedCastings: sameCasting)
        }

        // Otherwise the only matches are wishlist entries.
        let wantedTop = results.first(where: { $0.status == .wanted }) ?? top
        let sameWanted = wantedCars(cars, matching: wantedTop)
        return .onWishlist(primary: wantedTop, wantedCastings: sameWanted)
    }

    // MARK: - Casting grouping

    /// Every owned car sharing `reference`'s casting name (case/diacritic-insensitive), newest first.
    /// This is how all owned colorways of one casting are surfaced together.
    private func ownedCars(_ cars: [Car], matching reference: Car) -> [Car] {
        cars
            .filter { $0.status == .owned && sameCasting($0.castingName, reference.castingName) }
            .sorted { $0.dateAdded > $1.dateAdded }
    }

    private func wantedCars(_ cars: [Car], matching reference: Car) -> [Car] {
        cars
            .filter { $0.status == .wanted && sameCasting($0.castingName, reference.castingName) }
            .sorted { $0.dateAdded > $1.dateAdded }
    }

    private func sameCasting(_ lhs: String, _ rhs: String) -> Bool {
        lhs.compare(rhs, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }
}
