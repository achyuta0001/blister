import Foundation

extension Car {
    /// Recomputes the denormalised `searchKey`. Call on every save.
    ///
    /// The actual normalisation rules (spec §5) live in ``SearchNormalizer`` so the search feature
    /// owns that logic in one place. This method is the stable seam the model exposes; it must not
    /// change signature.
    func recomputeSearchKey() {
        searchKey = SearchNormalizer.key(for: self)
        castingKey = SearchNormalizer.normalize(castingName)
    }
}
