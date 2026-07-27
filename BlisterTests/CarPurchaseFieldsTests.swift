import Testing
import Foundation
@testable import Blister

/// The "only an owned car has purchase details" invariant (``CarPurchaseFields``).
///
/// This is the rule the edit form used to break: it wrote `purchasePriceINR` and `purchaseLocation`
/// unconditionally and never touched `purchaseDate`, so moving a car to the wishlist left it holding
/// a price it had been bought for. `resolved` is pure, so the decision the form makes on save is
/// checkable here without a `ModelContext`, a view, or a simulator.
struct CarPurchaseFieldsTests {

    private let price = Decimal(string: "1200")
    private let location = "Hamleys Phoenix Mall"
    private let boughtOn = Date(timeIntervalSince1970: 1_673_500_000)  // 12 Jan 2023

    // MARK: - resolved

    @Test func ownedKeepsAllThreeFields() {
        let fields = CarPurchaseFields.resolved(
            for: .owned, priceINR: price, location: location, date: boughtOn
        )
        #expect(fields.priceINR == price)
        #expect(fields.location == location)
        #expect(fields.date == boughtOn)
    }

    /// The core of the bug: a car filed onto the wishlist carries no purchase details, whatever was
    /// staged in the form.
    @Test func wantedClearsAllThreeFields() {
        let fields = CarPurchaseFields.resolved(
            for: .wanted, priceINR: price, location: location, date: boughtOn
        )
        #expect(fields == .cleared)
        #expect(fields.priceINR == nil)
        #expect(fields.location == nil)
        #expect(fields.date == nil)
    }

    @Test func ownedWithNothingEnteredIsStillCleared() {
        let fields = CarPurchaseFields.resolved(for: .owned, priceINR: nil, location: nil, date: nil)
        #expect(fields == .cleared)
    }

    // MARK: - apply(to:)

    /// The edit form's Garage → Wishlist move, end to end: every purchase field goes, including
    /// `purchaseDate`, which the old save path never wrote at all.
    @Test func movingACarToTheWishlistShedsEveryPurchaseField() {
        let car = Car(
            castingName: "'67 Camaro",
            colorway: "Spectraflame Blue",
            status: .owned,
            purchasePriceINR: price,
            purchaseDate: boughtOn,
            purchaseLocation: location
        )

        car.status = .wanted
        CarPurchaseFields.resolved(
            for: car.status, priceINR: price, location: location, date: car.purchaseDate
        ).apply(to: car)

        #expect(car.purchasePriceINR == nil)
        #expect(car.purchaseLocation == nil)
        #expect(car.purchaseDate == nil)
        // Nothing else about the car is touched.
        #expect(car.castingName == "'67 Camaro")
        #expect(car.colorway == "Spectraflame Blue")
    }

    /// The reverse move, and a plain Garage-side edit: staged values land on the car, and a date the
    /// form has no field for is carried through rather than erased.
    @Test func savingAnOwnedCarWritesTheStagedFields() {
        let car = Car(castingName: "Datsun 240Z", status: .wanted)

        car.status = .owned
        CarPurchaseFields.resolved(
            for: car.status, priceINR: price, location: location, date: boughtOn
        ).apply(to: car)

        #expect(car.purchasePriceINR == price)
        #expect(car.purchaseLocation == location)
        #expect(car.purchaseDate == boughtOn)
    }

    /// What ``CarEditView`` does with the date: it has no date field, so it passes the car's existing
    /// value straight back through.
    @Test func editingAnOwnedCarPreservesItsExistingPurchaseDate() {
        let car = Car(
            castingName: "Mazda RX-7",
            status: .owned,
            purchasePriceINR: Decimal(300),
            purchaseDate: boughtOn
        )

        CarPurchaseFields.resolved(
            for: car.status, priceINR: Decimal(450), location: nil, date: car.purchaseDate
        ).apply(to: car)

        #expect(car.purchasePriceINR == Decimal(450))
        #expect(car.purchaseDate == boughtOn)
    }

    /// ``FoundItSheet/undoMove()`` clears the same three fields by hand; both writers must agree on
    /// what "no purchase details" means.
    @Test func clearedMatchesTheUndoMovePath() {
        let undone = Car(castingName: "'67 Camaro", status: .owned,
                         purchasePriceINR: price, purchaseDate: boughtOn, purchaseLocation: location)
        undone.status = .wanted
        undone.purchaseDate = nil
        undone.purchasePriceINR = nil
        undone.purchaseLocation = nil

        let edited = Car(castingName: "'67 Camaro", status: .owned,
                         purchasePriceINR: price, purchaseDate: boughtOn, purchaseLocation: location)
        edited.status = .wanted
        CarPurchaseFields.cleared.apply(to: edited)

        #expect(edited.purchasePriceINR == undone.purchasePriceINR)
        #expect(edited.purchaseLocation == undone.purchaseLocation)
        #expect(edited.purchaseDate == undone.purchaseDate)
    }
}
