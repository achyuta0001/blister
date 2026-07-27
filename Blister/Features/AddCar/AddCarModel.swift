import SwiftUI
import Observation

/// Form state for the Add Car flow (spec §6.3). Holds the in-progress car entirely in memory: no
/// `Car` is inserted and no photo is written until the user taps Save, so force-quitting mid-add
/// loses at most this one draft and never orphans a file.
@Observable
final class AddCarModel {
    var castingName = ""
    var brand: Brand = .hotWheels
    var colorway = ""
    var series = ""
    var huntStatus: HuntStatus = .none
    var condition: Condition = .mintOnCard
    var pricePaid: Decimal?

    /// Whether this entry lands in the Garage (`.owned`) or on the Wishlist (`.wanted`). Seeded from
    /// the presenting screen — Wishlist's "+" opens the form already set to `.wanted` — and freely
    /// switchable in the form.
    var status: CollectionStatus = .owned

    /// A reference value the user explicitly entered/adjusted. When `nil`, an applied catalog
    /// entry's reference price (``appliedCatalogPriceINR``) is used on save instead — never overwriting
    /// a user value.
    var estimatedValueINR: Decimal?

    /// Reference price from the last-applied catalog entry, surfaced as a caption and used as the
    /// `estimatedValueINR` fallback on save. Cleared by ``reset()``.
    private(set) var appliedCatalogPriceINR: Decimal?

    /// Series/reference caption for the applied catalog entry, shown under the casting-name field.
    private(set) var appliedCatalogSummary: String?

    /// The captured or picked photo, kept in memory until Save.
    var capturedImage: UIImage?

    /// Ranked casting-name candidates from on-device OCR of `capturedImage` (best first). Presented
    /// as tappable "Suggested" chips under the casting-name field.
    var nameCandidates: [String] = []

    /// True while OCR is running for the current image, so the UI can show a progress indicator.
    var isRecognizingText = false

    /// Specific catalog castings identified from the card photo by fusing OCR with the catalog
    /// (v2.2 step 2). Best first. Presented as "Identified from card" chips that fill the whole
    /// entry (name/brand/series + reference price) on tap.
    var identifiedCatalogEntries: [CatalogEntry] = []

    init(status: CollectionStatus = .owned) {
        self.status = status
    }

    /// Casting name is the one required field (spec §6.3).
    var isValid: Bool {
        !castingName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Applies a catalog entry: fills the casting name, and brand/series only where the user hasn't
    /// already typed something, then stashes the reference price + summary for the save fallback and
    /// caption. Never clobbers a user-entered brand/series.
    func apply(_ entry: CatalogEntry) {
        castingName = entry.castingName
        brand = entry.brand
        if series.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let entrySeries = entry.series {
            series = entrySeries
        }
        appliedCatalogPriceINR = entry.referencePriceINR
        appliedCatalogSummary = Self.summary(for: entry)
    }

    private static func summary(for entry: CatalogEntry) -> String {
        var parts: [String] = [entry.brand.displayName]
        if let series = entry.series { parts.append(series) }
        let head = parts.joined(separator: " · ")
        guard let price = entry.priceINR else { return head }
        return String(localized: "\(head) · reference ≈ ₹\(price)")
    }

    /// Clears every field so "Save and add another" starts fresh.
    ///
    /// ``status`` is deliberately **kept**, not reset to `.owned`: this exists for batch entry, and a
    /// collector working through a wishlist adds several wanted cars in a row. Silently flipping each
    /// subsequent entry back to the Garage would file cars in the wrong place without them noticing.
    func reset() {
        castingName = ""
        brand = .hotWheels
        colorway = ""
        series = ""
        huntStatus = .none
        condition = .mintOnCard
        pricePaid = nil
        estimatedValueINR = nil
        appliedCatalogPriceINR = nil
        appliedCatalogSummary = nil
        capturedImage = nil
        nameCandidates = []
        isRecognizingText = false
        identifiedCatalogEntries = []
    }

    /// Builds a `Car` from the current form values. The caller inserts it and saves. The estimated
    /// value prefers a user-entered figure, else falls back to an applied catalog reference price.
    func makeCar(photoFilenames: [String]) -> Car {
        Car(
            castingName: castingName.trimmingCharacters(in: .whitespacesAndNewlines),
            brand: brand,
            series: Self.trimmedOrNil(series),
            colorway: Self.trimmedOrNil(colorway),
            huntStatus: huntStatus,
            condition: condition,
            purchasePriceINR: pricePaid,
            estimatedValueINR: estimatedValueINR ?? appliedCatalogPriceINR,
            photoFilenames: photoFilenames
        )
    }

    private static func trimmedOrNil(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
