import Foundation

/// Pure duplicate-detection for the Add Car flow (spec §6.3). Collectors legitimately own multiples,
/// so this never hard-blocks — it only tells the view whether a car with the same casting name and
/// colorway already exists *on the list being added to*, so the UI can warn before inserting.
///
/// The list matters, which is why every entry point takes a status. Two identical cars in the garage
/// is a real thing a collector does on purpose; two identical rows on the wishlist is always a
/// mistake, because a wishlist row means "find me one of these" and you only need to be told once.
/// Matching one list at a time also keeps the two warnings from crossing: an owned car is not a
/// reason to refuse a wishlist entry (people buy spares), and vice versa.
///
/// Matching is case- and diacritic-insensitive, reusing ``SearchNormalizer`` so it lines up with the
/// rest of the app's text handling. A missing colorway normalises to an empty string, so two cars
/// with no colorway are treated as the same colorway.
enum DuplicateCarDetector {

    /// True when `car` sits on the given list and shares a normalised casting name *and* colorway
    /// with the supplied values. Cars on the other list never count.
    static func isDuplicate(
        castingName: String,
        colorway: String?,
        status: CollectionStatus,
        of car: Car
    ) -> Bool {
        guard car.status == status else { return false }
        return SearchNormalizer.normalize(castingName) == SearchNormalizer.normalize(car.castingName)
            && SearchNormalizer.normalize(colorway ?? "") == SearchNormalizer.normalize(car.colorway ?? "")
    }

    /// True when any car in `cars` on the given list matches the supplied casting name and colorway.
    static func duplicateExists(
        castingName: String,
        colorway: String?,
        status: CollectionStatus,
        in cars: [Car]
    ) -> Bool {
        cars.contains {
            isDuplicate(castingName: castingName, colorway: colorway, status: status, of: $0)
        }
    }
}
