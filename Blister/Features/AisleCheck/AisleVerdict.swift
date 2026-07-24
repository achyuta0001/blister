import Foundation

/// The answer Aisle Check gives while the user stands in the shop (spec §6.1). Computed purely from
/// the current query / scanned barcode against the collection — carries no SwiftData or view state,
/// so it stays trivially testable. Owned by Agent 4.
enum AisleVerdict: Equatable {
    /// Nothing typed or scanned yet — prompt the user to search.
    case idle

    /// A match the user already owns. `primary` drives the photo; `ownedCastings` are every owned
    /// car of the same casting so the colorways can be disambiguated (a red and a blue are different
    /// items — spec §6.1).
    case inCollection(primary: Car, ownedCastings: [Car])

    /// No owned match, but the casting is on the wishlist. Useful mid-aisle: "you wanted this".
    case onWishlist(primary: Car, wantedCastings: [Car])

    /// The typed query matched nothing you own or want. `catalogHint` is a known casting from the
    /// bundled reference catalog (if one matches), so the miss can still say "this is a real casting,
    /// typically ≈ ₹X" and offer a one-tap add.
    case notInCollection(query: String, catalogHint: CatalogEntry?)

    /// A scanned barcode matched owned/wanted cars. A hint, never proof: barcodes are frequently
    /// shared across a whole assortment (spec §6.1), so these are candidates to eyeball, not a verdict.
    case barcodeHint(matches: [Car])

    /// A scanned barcode matched nothing on file.
    case barcodeMiss(barcode: String)
}
