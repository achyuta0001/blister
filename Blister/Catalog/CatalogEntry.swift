import Foundation

/// One known die-cast casting in the bundled reference catalog (spec §v2.3).
///
/// This is read-only reference data shipped in the app bundle — **not** a SwiftData model — so it
/// never enters the user's `Car` store or CloudKit sync. Prices are static India-market
/// approximations, refreshed per app update (the spec's "no scraping / no live feed" stance).
struct CatalogEntry: Codable, Identifiable, Sendable, Hashable {
    /// Stable id (slug), used for `Identifiable` and dedupe.
    let id: String
    let castingName: String
    let brand: Brand
    let series: String?
    /// Approximate India reference price in whole rupees; `nil` when unknown. Whole rupees keeps
    /// money off `Double` (spec) while staying compact in JSON.
    let priceINR: Int?

    /// The reference price as `Decimal`, suitable for `Car.estimatedValueINR`.
    var referencePriceINR: Decimal? { priceINR.map { Decimal($0) } }
}
