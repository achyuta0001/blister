import Foundation

/// Fuses on-device OCR output (v2.2 step 1) with the bundled catalog (v2.3) to identify the specific
/// casting on a card — the license-clean, dataset-free stand-in for a trained image classifier
/// (v2.2 step 2). Each OCR candidate line is matched against the catalog; results are ranked so an
/// earlier (more prominent) OCR line and a stronger catalog match float to the top.
///
/// Pure and deterministic: the catalog is read-only, so this is unit-testable with a fixed store.
enum CatalogMatcher {

    /// Ranked catalog entries identified from ordered OCR candidate strings (most prominent first),
    /// best first, capped at `limit`. Returns `[]` when nothing matches — identification is a hint.
    static func matches(for ocrCandidates: [String],
                        in catalog: CatalogStore,
                        limit: Int = 3) -> [CatalogEntry] {
        // Lower score = better. An entry keeps its best score across all OCR lines that hit it.
        var bestScore: [String: Int] = [:]
        var entryByID: [String: CatalogEntry] = [:]

        for (lineIndex, candidate) in ocrCandidates.enumerated() {
            let results = catalog.search(candidate, limit: limit)
            for (rank, entry) in results.enumerated() {
                // Weight the OCR line order more heavily than the within-line catalog rank.
                let score = lineIndex * 10 + rank
                if let existing = bestScore[entry.id], existing <= score { continue }
                bestScore[entry.id] = score
                entryByID[entry.id] = entry
            }
        }

        return bestScore
            .sorted { lhs, rhs in
                lhs.value == rhs.value
                    ? (entryByID[lhs.key]?.castingName ?? "")
                        .localizedCaseInsensitiveCompare(entryByID[rhs.key]?.castingName ?? "") == .orderedAscending
                    : lhs.value < rhs.value
            }
            .prefix(limit)
            .compactMap { entryByID[$0.key] }
    }
}
