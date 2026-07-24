import Foundation

/// Ranks a collection against a free-text query. Implemented by the search feature (spec §5);
/// consumed by Aisle Check and Garage. This protocol is a frozen contract — do not change its
/// shape without updating every call site.
protocol SearchEngine: Sendable {
    /// Returns matching cars ordered by relevance tier, then `dateAdded` descending.
    /// An empty or whitespace-only query returns `cars` unchanged (caller decides how to display).
    func search(_ query: String, in cars: [Car]) -> [Car]
}
