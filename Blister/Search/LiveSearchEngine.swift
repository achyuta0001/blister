import Foundation

/// Production ``SearchEngine``. **Owned by the Search feature (Agent 1).**
///
/// Filters an already-fetched array in memory (spec §5, never a per-keystroke SwiftData predicate)
/// and ranks every match into one of four tiers, best first:
///
/// 1. Exact match on the normalised casting name.
/// 2. Prefix match — a query token is the prefix of some casting-name token.
/// 3. Token subset — every query token appears (order-independent) in the car's `searchKey`.
/// 4. Fuzzy — a query token is within Levenshtein distance 2 of some `searchKey` token,
///    so one-handed phone typos still land.
///
/// Results are sorted by tier, then `dateAdded` descending. Non-matching cars are dropped.
struct LiveSearchEngine: SearchEngine {

    func search(_ query: String, in cars: [Car]) -> [Car] {
        let queryTokens = SearchNormalizer.tokens(in: query)
        // Contract: an empty / whitespace-only query returns the input unchanged.
        guard !queryTokens.isEmpty else { return cars }
        let normalizedQuery = queryTokens.joined(separator: " ")

        let ranked: [(car: Car, tier: Int)] = cars.compactMap { car in
            guard let tier = Self.tier(
                for: car,
                queryTokens: queryTokens,
                normalizedQuery: normalizedQuery
            ) else { return nil }
            return (car, tier)
        }

        return ranked
            .sorted { lhs, rhs in
                lhs.tier == rhs.tier
                    ? lhs.car.dateAdded > rhs.car.dateAdded
                    : lhs.tier < rhs.tier
            }
            .map(\.car)
    }

    /// The best (lowest-numbered) tier `car` satisfies, or `nil` if it matches none. Tiers are
    /// checked cheapest-first so the expensive fuzzy pass only runs when nothing else matched.
    private static func tier(
        for car: Car,
        queryTokens: [String],
        normalizedQuery: String
    ) -> Int? {
        // Precomputed on save (denormalised, spec §5) — avoids re-folding the casting name on every
        // keystroke across the whole collection.
        let castingNormalized = car.castingKey

        // Tier 1 — exact casting-name match.
        if castingNormalized == normalizedQuery { return 1 }

        // Tier 2 — any query token is a prefix of any casting-name token.
        let castingTokens = castingNormalized.split(separator: " ")
        if queryTokens.contains(where: { q in
            castingTokens.contains { $0.hasPrefix(q) }
        }) {
            return 2
        }

        // Tier 3 — every query token is present as a whole token in the search key.
        let keyTokens = Set(car.searchKey.split(separator: " ").map(String.init))
        if queryTokens.allSatisfy({ keyTokens.contains($0) }) {
            return 3
        }

        // Tier 4 — fuzzy: a query token within edit distance 2 of a key token. Guarded to tokens of
        // length >= 4 so short words don't collapse into each other, and pruned by length delta.
        for q in queryTokens where q.count >= 4 {
            for k in keyTokens where abs(k.count - q.count) <= 2 {
                if levenshtein(q, k) <= 2 { return 4 }
            }
        }

        return nil
    }

    /// Classic two-row Levenshtein edit distance.
    private static func levenshtein(_ lhs: String, _ rhs: String) -> Int {
        let source = Array(lhs)
        let target = Array(rhs)
        if source.isEmpty { return target.count }
        if target.isEmpty { return source.count }

        var previous = Array(0...target.count)
        var current = [Int](repeating: 0, count: target.count + 1)

        for i in 1...source.count {
            current[0] = i
            for j in 1...target.count {
                let cost = source[i - 1] == target[j - 1] ? 0 : 1
                current[j] = min(
                    previous[j] + 1,      // deletion
                    current[j - 1] + 1,   // insertion
                    previous[j - 1] + cost // substitution
                )
            }
            swap(&previous, &current)
        }
        return previous[target.count]
    }
}
