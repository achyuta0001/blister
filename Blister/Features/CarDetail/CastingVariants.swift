import Foundation

/// Finds the cars in a collection that are variants of the same casting (spec §6.4) — the set behind
/// Car Detail's "you own N variants of this casting" link and the list it opens.
///
/// Pure, and shared by both so they cannot drift: they previously each carried their own copy of the
/// filter and each was missing the `status == .owned` half of it, so a wishlisted '67 Camaro was
/// counted as one the collector owned and listed at a blank price. Owned-only is the whole point —
/// the label says *own*, and a wishlist car is one that is still being hunted.
///
/// The status check runs in memory rather than in a `#Predicate`/`@Query`: `CollectionStatus` is a
/// `Codable` enum, which SwiftData predicates either crash on or silently match nothing against.
enum CastingVariants {

    /// Owned cars whose casting name normalises to the same key as `castingName`.
    ///
    /// - Parameter excluding: an id to leave out — Car Detail passes the car being viewed, so the
    ///   result is the *other* variants. Omit it to include every match.
    /// - Returns: the matches in `cars` order; empty when the name normalises to nothing.
    static func owned(
        matching castingName: String,
        in cars: [Car],
        excluding excludedID: UUID? = nil
    ) -> [Car] {
        let key = SearchNormalizer.normalize(castingName)
        guard !key.isEmpty else { return [] }
        return cars.filter { car in
            car.status == .owned
                && car.id != excludedID
                && SearchNormalizer.normalize(car.castingName) == key
        }
    }

    /// How many of the casting the collector owns in total, counting `car` itself only when it is
    /// owned — viewing a wishlist car, adding one for "this one" would be counting a car they have
    /// not bought.
    static func ownedCount(including car: Car, in cars: [Car]) -> Int {
        let others = owned(matching: car.castingName, in: cars, excluding: car.id)
        return others.count + (car.status == .owned ? 1 : 0)
    }
}
