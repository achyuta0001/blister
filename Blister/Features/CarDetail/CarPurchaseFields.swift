import Foundation

/// The three purchase fields a ``Car`` carries — price paid, where, and when — resolved against the
/// list the car is being filed into.
///
/// The invariant this encodes: **only an owned car has purchase details.** A wanted car has not been
/// bought, so it holds none — `purchasePriceINR` means "what I paid", never "what I hope to pay".
/// ``AddCarModel/makeCar(photoFilenames:)`` and ``FoundItSheet``'s undo already hold it; ``CarEditView``
/// can move a car in either direction, so it has to as well. Clearing must cover all three fields
/// together: ``CollectionStats/compute(from:)`` sums `purchasePriceINR` across *every* car regardless
/// of status, so a stale price on a wishlist car inflates Settings' "total spent" with money the
/// collector never spent.
///
/// It is a value type on purpose. ``resolved(for:priceINR:location:date:)`` is pure, so the edit
/// form's save decision is unit-testable without a `ModelContext`, a view, or a simulator — which is
/// what was missing when the stale-price bug shipped.
struct CarPurchaseFields: Equatable {
    var priceINR: Decimal?
    var location: String?
    var date: Date?

    /// No purchase details at all — what a wanted car holds.
    static let cleared = CarPurchaseFields(priceINR: nil, location: nil, date: nil)

    /// The purchase fields a car should end up with, given the list it is being saved into and the
    /// values currently staged in the form. Saving into the wishlist drops all three.
    static func resolved(
        for status: CollectionStatus,
        priceINR: Decimal?,
        location: String?,
        date: Date?
    ) -> CarPurchaseFields {
        guard status == .owned else { return .cleared }
        return CarPurchaseFields(priceINR: priceINR, location: location, date: date)
    }

    /// Writes the resolved fields onto a car. Kept separate from the resolution above so the decision
    /// stays pure and only this one step touches the model.
    func apply(to car: Car) {
        car.purchasePriceINR = priceINR
        car.purchaseLocation = location
        car.purchaseDate = date
    }
}
