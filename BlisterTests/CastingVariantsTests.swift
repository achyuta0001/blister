import Testing
import Foundation
@testable import Blister

/// The "you own N variants of this casting" set (spec §6.4). Both Car Detail's count and the list it
/// opens read this, so the rule is checked once here.
struct CastingVariantsTests {

    private func camaro(_ colorway: String, _ status: CollectionStatus) -> Car {
        Car(castingName: "'67 Camaro", colorway: colorway, status: status)
    }

    // MARK: - Owned-only

    /// The bug: a wishlisted '67 Camaro was counted as one the collector owned, so an owned car with
    /// one wishlisted twin read "You own 2 variants" and listed the wishlist car at a blank price.
    @Test func wishlistCarsAreNotVariants() {
        let mine = camaro("Spectraflame Blue", .owned)
        let wanted = camaro("Spectraflame Red", .wanted)

        #expect(CastingVariants.owned(matching: "'67 Camaro", in: [mine, wanted], excluding: mine.id).isEmpty)
        #expect(CastingVariants.ownedCount(including: mine, in: [mine, wanted]) == 1)
    }

    @Test func ownedCarsWithTheSameCastingAreVariants() {
        let mine = camaro("Spectraflame Blue", .owned)
        let other = camaro("Spectraflame Red", .owned)
        let cars = [mine, other]

        let variants = CastingVariants.owned(matching: "'67 Camaro", in: cars, excluding: mine.id)
        #expect(variants.count == 1)
        #expect(variants.first?.id == other.id)
        #expect(CastingVariants.ownedCount(including: mine, in: cars) == 2)
    }

    /// Matching goes through ``SearchNormalizer``, so the `'67` / `67` / `1967` year convention and
    /// casing all land on the same casting.
    @Test func matchingIsNormalised() {
        let mine = camaro("Blue", .owned)
        let other = Car(castingName: "1967 CAMARO", colorway: "Red", status: .owned)

        #expect(CastingVariants.ownedCount(including: mine, in: [mine, other]) == 2)
    }

    @Test func differentCastingsAreNotVariants() {
        let mine = camaro("Blue", .owned)
        let other = Car(castingName: "Datsun 240Z", status: .owned)

        #expect(CastingVariants.owned(matching: "'67 Camaro", in: [mine, other], excluding: mine.id).isEmpty)
        #expect(CastingVariants.ownedCount(including: mine, in: [mine, other]) == 1)
    }

    // MARK: - Counting the car on screen

    /// Viewing a wishlist car, the collector owns only the cars they actually own — the one on screen
    /// isn't one of them, so it must not add itself to the count.
    @Test func viewingAWishlistCarDoesNotCountItself() {
        let wanted = camaro("Spectraflame Red", .wanted)
        let owned = camaro("Spectraflame Blue", .owned)

        #expect(CastingVariants.ownedCount(including: wanted, in: [wanted, owned]) == 1)
        #expect(CastingVariants.ownedCount(including: wanted, in: [wanted]) == 0)
    }

    /// The link is drawn from two upward, so a lone owned car shows nothing.
    @Test func aSingleOwnedCarHasNoVariantsToShow() {
        let mine = camaro("Blue", .owned)
        #expect(CastingVariants.ownedCount(including: mine, in: [mine]) == 1)
    }

    // MARK: - Edges

    /// Omitting the exclusion is what ``CastingVariantsView`` does — it lists every owned match,
    /// including the car that was being viewed.
    @Test func withoutAnExclusionEveryOwnedMatchIsIncluded() {
        let mine = camaro("Blue", .owned)
        let other = camaro("Red", .owned)
        #expect(CastingVariants.owned(matching: "'67 Camaro", in: [mine, other]).count == 2)
    }

    /// A blank casting name normalises to nothing and must not gather up every other blank-named car
    /// — the count stays at "just this one", below the threshold that draws the link.
    @Test func blankCastingNameMatchesNothing() {
        let blank = Car(castingName: "  ", status: .owned)
        let another = Car(castingName: "", status: .owned)
        #expect(CastingVariants.owned(matching: "  ", in: [blank, another]).isEmpty)
        #expect(CastingVariants.ownedCount(including: blank, in: [blank, another]) == 1)
    }
}
