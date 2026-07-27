import Testing
import Foundation
@testable import Blister

/// Form state for Add Car (spec §6.3), focused on the Garage/Wishlist choice: the form must be able
/// to create a wanted car, carry that choice into the saved `Car`, and hold onto it across the
/// "Save and add another" reset.
@MainActor
struct AddCarModelTests {

    // MARK: - Status carries into the built car

    /// Nothing passed → the Garage, matching `Car`'s own default and the pre-existing presenters.
    @Test func defaultsToOwned() {
        let model = AddCarModel()
        model.castingName = "Datsun 240Z"
        #expect(model.status == .owned)
        #expect(model.makeCar(photoFilenames: []).status == .owned)
    }

    /// Wishlist's "+" seeds the form, and that has to survive into the inserted car — otherwise the
    /// car silently lands in the Garage (the original bug).
    @Test func seededWantedStatusReachesTheCar() {
        let model = AddCarModel(status: .wanted)
        model.castingName = "'67 Camaro"
        #expect(model.status == .wanted)
        #expect(model.makeCar(photoFilenames: []).status == .wanted)
    }

    /// Flipping the picker mid-form is honoured, in both directions.
    @Test func statusChangedInFormReachesTheCar() {
        let model = AddCarModel()
        model.castingName = "Nissan Skyline"
        model.status = .wanted
        #expect(model.makeCar(photoFilenames: []).status == .wanted)

        let reverse = AddCarModel(status: .wanted)
        reverse.castingName = "Toyota Supra"
        reverse.status = .owned
        #expect(reverse.makeCar(photoFilenames: []).status == .owned)
    }

    // MARK: - Price paid only applies to a car you actually own

    @Test func ownedCarKeepsPricePaid() {
        let model = AddCarModel(status: .owned)
        model.castingName = "Mazda RX-7"
        model.pricePaid = Decimal(string: "349.50")
        #expect(model.makeCar(photoFilenames: []).purchasePriceINR == Decimal(string: "349.50"))
    }

    /// The form hides the price field for a wanted car; a stale value typed before the flip must not
    /// leak into `purchasePriceINR`, which means "what I paid".
    @Test func wantedCarCarriesNoPricePaid() {
        let model = AddCarModel(status: .owned)
        model.castingName = "Mazda RX-7"
        model.pricePaid = Decimal(string: "349.50")
        model.status = .wanted
        #expect(model.makeCar(photoFilenames: []).purchasePriceINR == nil)
    }

    // MARK: - reset()

    /// "Save and add another" is batch entry: someone working through a wishlist adds several wanted
    /// cars in a row, so the status is the one field `reset()` deliberately keeps.
    @Test func resetKeepsWantedStatus() {
        let model = AddCarModel(status: .wanted)
        model.castingName = "'67 Camaro"
        model.reset()
        #expect(model.status == .wanted)
    }

    @Test func resetKeepsOwnedStatus() {
        let model = AddCarModel(status: .owned)
        model.castingName = "'67 Camaro"
        model.reset()
        #expect(model.status == .owned)
    }

    /// Everything except the status still clears, so the kept status isn't hiding a broken reset.
    @Test func resetClearsTheRestOfTheForm() {
        let model = AddCarModel(status: .wanted)
        model.castingName = "'67 Camaro"
        model.colorway = "Spectraflame Blue"
        model.series = "Car Culture"
        model.brand = .matchbox
        model.huntStatus = .treasureHunt
        model.condition = .loose
        model.pricePaid = Decimal(200)
        model.estimatedValueINR = Decimal(900)
        model.nameCandidates = ["Camaro"]

        model.reset()

        #expect(model.castingName.isEmpty)
        #expect(model.colorway.isEmpty)
        #expect(model.series.isEmpty)
        #expect(model.brand == .hotWheels)
        #expect(model.huntStatus == .none)
        #expect(model.condition == .mintOnCard)
        #expect(model.pricePaid == nil)
        #expect(model.estimatedValueINR == nil)
        #expect(model.nameCandidates.isEmpty)
        #expect(!model.isValid)
        #expect(model.status == .wanted)
    }

    /// Batch-adding wanted cars must never trip the "you already own this" confirmation over the
    /// entries it just made — the garage check only ever looks at owned cars.
    @Test func wantedEntriesDoNotBecomeTheirOwnGarageDuplicates() {
        let model = AddCarModel(status: .wanted)
        model.castingName = "'67 Camaro"
        model.colorway = "Spectraflame Blue"
        let first = model.makeCar(photoFilenames: [])

        model.reset()
        model.castingName = "'67 Camaro"
        model.colorway = "Spectraflame Blue"

        #expect(!DuplicateCarDetector.duplicateExists(
            castingName: model.castingName,
            colorway: model.colorway,
            status: .owned,
            in: [first]
        ))
    }
}
