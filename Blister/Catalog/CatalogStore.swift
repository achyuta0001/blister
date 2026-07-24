import Foundation
import os

/// In-memory, read-only store over the bundled ``CatalogEntry`` reference data (spec §v2.3).
///
/// Loaded once from `catalog.json` in the app bundle. Deliberately not SwiftData: it never syncs and
/// needs no migration. Search reuses ``SearchNormalizer`` so catalog matching and collection search
/// tokenise identically. Immutable after construction, hence `Sendable`.
final class CatalogStore: Sendable {
    /// The app-wide catalog, loaded from the bundle on first access.
    static let shared = CatalogStore()

    let entries: [CatalogEntry]

    /// Precomputed normalisation for each entry, parallel to `entries`, so search never re-folds.
    private let indexed: [Indexed]

    private struct Indexed: Sendable {
        let entry: CatalogEntry
        let castingKey: String  // normalised casting name
        let searchKey: String   // casting + series, normalised
    }

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Blister",
                                       category: "CatalogStore")

    /// Loads `catalog.json` from the bundle containing this type. On any failure the catalog is empty
    /// (logged) — the app still runs, features just show no catalog matches.
    private init() {
        let bundle = Bundle(for: CatalogStore.self)
        guard let url = bundle.url(forResource: "catalog", withExtension: "json") else {
            Self.logger.error("catalog.json not found in bundle")
            self.entries = []
            self.indexed = []
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([CatalogEntry].self, from: data)
            self.entries = decoded
            self.indexed = decoded.map(Self.index(_:))
        } catch {
            Self.logger.error("catalog.json decode failed: \(error.localizedDescription, privacy: .public)")
            self.entries = []
            self.indexed = []
        }
    }

    /// Testable initialiser with in-memory entries (no bundle access).
    init(entries: [CatalogEntry]) {
        self.entries = entries
        self.indexed = entries.map(Self.index(_:))
    }

    private static func index(_ entry: CatalogEntry) -> Indexed {
        let casting = SearchNormalizer.normalize(entry.castingName)
        let search = SearchNormalizer.normalize([entry.castingName, entry.series ?? ""]
            .joined(separator: " "))
        return Indexed(entry: entry, castingKey: casting, searchKey: search)
    }

    // MARK: - Query

    /// Ranked catalog matches for a partial query, best first, capped at `limit`. Empty query → none.
    /// Tiers (mirrors ``LiveSearchEngine`` but simpler): exact casting → prefix token → token subset.
    func search(_ query: String, limit: Int = 6) -> [CatalogEntry] {
        let queryTokens = SearchNormalizer.tokens(in: query)
        guard !queryTokens.isEmpty else { return [] }
        let normalizedQuery = queryTokens.joined(separator: " ")

        let ranked: [(entry: CatalogEntry, tier: Int)] = indexed.compactMap { item in
            guard let tier = Self.tier(for: item,
                                       queryTokens: queryTokens,
                                       normalizedQuery: normalizedQuery) else { return nil }
            return (item.entry, tier)
        }

        return ranked
            .sorted { lhs, rhs in
                lhs.tier == rhs.tier
                    ? lhs.entry.castingName.localizedCaseInsensitiveCompare(rhs.entry.castingName) == .orderedAscending
                    : lhs.tier < rhs.tier
            }
            .prefix(limit)
            .map(\.entry)
    }

    /// The catalog entry whose casting name matches `name` exactly (normalised, so case/diacritic
    /// insensitive). Used for the Aisle Check "known casting" hint and price suggestion.
    func entry(matchingCasting name: String) -> CatalogEntry? {
        let key = SearchNormalizer.normalize(name)
        guard !key.isEmpty else { return nil }
        return indexed.first(where: { $0.castingKey == key })?.entry
    }

    private static func tier(for item: Indexed,
                             queryTokens: [String],
                             normalizedQuery: String) -> Int? {
        // Tier 1 — exact casting-name match.
        if item.castingKey == normalizedQuery { return 1 }

        // Tier 2 — any query token is a prefix of any casting-name token.
        let castingTokens = item.castingKey.split(separator: " ")
        if queryTokens.contains(where: { q in castingTokens.contains { $0.hasPrefix(q) } }) {
            return 2
        }

        // Tier 3 — every query token is present as a whole token in the search key.
        let keyTokens = Set(item.searchKey.split(separator: " ").map(String.init))
        if queryTokens.allSatisfy({ keyTokens.contains($0) }) {
            return 3
        }

        return nil
    }
}
