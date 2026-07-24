import Foundation

/// Text normalisation for search (spec §5). **Owned by the Search feature (Agent 1).**
///
/// Normalisation rules: lowercase, strip apostrophes and punctuation, collapse whitespace, strip
/// diacritics, and canonicalise the leading-apostrophe year convention so `'67` / `67` and `1967`
/// all collapse to a single 4-digit token. Because the *same* canonicalisation runs over both the
/// stored ``Car/searchKey`` and every query, `'67` is matchable as `1967` and `1967` as `67`
/// without any additive token bloat (which would otherwise break order-independent subset matching).
enum SearchNormalizer {

    /// Normalises an arbitrary query or field into a comparable, space-joined form.
    static func normalize(_ text: String) -> String {
        tokens(in: text).joined(separator: " ")
    }

    /// Splits `text` into normalised, year-canonicalised tokens. Shared by ``normalize(_:)`` and the
    /// engine so query and key tokenisation can never drift apart.
    static func tokens(in text: String) -> [String] {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\u{2019}", with: "") // right single quote
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .map(canonicalYear)
    }

    /// Builds the denormalised `searchKey` for a car (spec §5): casting name + series + colorway +
    /// collector number + tags, normalised.
    static func key(for car: Car) -> String {
        let parts = [
            car.castingName,
            car.series ?? "",
            car.colorway ?? "",
            car.collectorNumber ?? "",
            car.tags.joined(separator: " ")
        ]
        return normalize(parts.joined(separator: " "))
    }

    // MARK: - Year convention

    /// Two-digit years before this value are read as 2000s, at or after it as 1900s. Die-cast model
    /// years span the mid-1900s to the present, so 30 keeps `'67` in 1967 and `'21` in 2021.
    private static let yearPivot = 30

    /// Collapses a bare two-digit year to its canonical four-digit form (`67` → `1967`). All other
    /// tokens — including already four-digit years like `1967` — pass through unchanged, so every
    /// spelling of a given year canonicalises to the same token on both the key and query sides.
    private static func canonicalYear(_ token: String) -> String {
        guard token.count == 2, let value = Int(token) else { return token }
        let century = value >= yearPivot ? 1900 : 2000
        return String(century + value)
    }
}
