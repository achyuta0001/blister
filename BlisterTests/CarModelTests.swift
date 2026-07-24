import Testing
import Foundation
@testable import Blister

/// Model-level sanity checks. The search ranking + performance suite (spec §5) is added by the
/// Search agent in its own file under this target.
struct CarModelTests {

    @Test func searchKeyIsComputedOnInit() {
        let car = Car(castingName: "'67 Camaro", series: "Car Culture: Japan Historics")
        #expect(!car.searchKey.isEmpty)
        #expect(car.searchKey.contains("camaro"))
    }

    @Test func recomputeReflectsEdits() {
        let car = Car(castingName: "Datsun 240Z")
        car.colorway = "Green"
        car.recomputeSearchKey()
        #expect(car.searchKey.contains("green"))
    }

    @Test func moneyUsesDecimalNotDouble() {
        let car = Car(castingName: "x", purchasePriceINR: Decimal(string: "1299.50"))
        #expect(car.purchasePriceINR == Decimal(string: "1299.50"))
    }
}
