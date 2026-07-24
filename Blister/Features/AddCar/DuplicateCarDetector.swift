import Foundation

/// Pure duplicate-detection for the Add Car flow (spec §6.3). Collectors legitimately own multiples,
/// so this never hard-blocks — it only tells the view whether an *owned* car with the same casting
/// name and colorway already exists, so the UI can warn before inserting.
///
/// Matching is case- and diacritic-insensitive, reusing ``SearchNormalizer`` so it lines up with the
/// rest of the app's text handling. A missing colorway normalises to an empty string, so two cars
/// with no colorway are treated as the same colorway.
enum DuplicateCarDetector {

    /// True when `car` is owned and shares a normalised casting name *and* colorway with the given
    /// values. Wanted (wishlist) cars never count as duplicates.
    static func isDuplicate(castingName: String, colorway: String?, of car: Car) -> Bool {
        guard car.status == .owned else { return false }
        return SearchNormalizer.normalize(castingName) == SearchNormalizer.normalize(car.castingName)
            && SearchNormalizer.normalize(colorway ?? "") == SearchNormalizer.normalize(car.colorway ?? "")
    }

    /// True when any owned car in `cars` matches the given casting name and colorway.
    static func ownedDuplicateExists(castingName: String, colorway: String?, in cars: [Car]) -> Bool {
        cars.contains { isDuplicate(castingName: castingName, colorway: colorway, of: $0) }
    }
}
