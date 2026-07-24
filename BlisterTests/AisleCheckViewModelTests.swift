import Testing
import Foundation
@testable import Blister

/// Verdict logic for Aisle Check (spec §6.1). Drives ``AisleCheckViewModel`` as a pure transform:
/// query / scanned barcode + a fixed `[Car]` (and an injected catalog) → ``AisleVerdict``.
@MainActor
struct AisleCheckViewModelTests {

    /// An in-memory catalog so the "known casting" hint is testable without the bundled JSON.
    private func makeCatalog() -> CatalogStore {
        CatalogStore(entries: [
            CatalogEntry(id: "skyline-r34", castingName: "Nissan Skyline GT-R R34",
                         brand: .hotWheels, series: "Car Culture", priceINR: 450),
            CatalogEntry(id: "supra", castingName: "Toyota Supra",
                         brand: .hotWheels, series: "Boulevard", priceINR: 500),
        ])
    }

    private func makeViewModel(catalog: CatalogStore? = nil) -> AisleCheckViewModel {
        AisleCheckViewModel(searchEngine: LiveSearchEngine(),
                            catalog: catalog ?? makeCatalog())
    }

    // MARK: - Idle

    /// Empty query with nothing scanned → `.idle`.
    @Test func emptyQueryIsIdle() {
        let vm = makeViewModel()
        vm.query = "   "
        #expect(vm.verdict(from: []) == .idle)
    }

    // MARK: - In collection

    /// A query matching an owned car reports `.inCollection`, grouping every owned colorway of that casting.
    @Test func ownedQueryGroupsAllColorways() {
        let redCamaro = Car(castingName: "'67 Camaro", colorway: "Red", status: .owned)
        let blueCamaro = Car(castingName: "'67 Camaro", colorway: "Spectraflame Blue", status: .owned)
        let decoy = Car(castingName: "Datsun 240Z", status: .owned)
        let vm = makeViewModel()
        vm.query = "camaro"

        let verdict = vm.verdict(from: [redCamaro, blueCamaro, decoy])
        if case let .inCollection(primary, ownedCastings) = verdict {
            #expect(primary.castingName == "'67 Camaro")
            #expect(ownedCastings.contains { $0.id == redCamaro.id })
            #expect(ownedCastings.contains { $0.id == blueCamaro.id })
            #expect(!ownedCastings.contains { $0.id == decoy.id })
        } else {
            Issue.record("expected .inCollection, got \(verdict)")
        }
    }

    // MARK: - On wishlist

    /// A query matching only wishlist cars (nothing owned) reports `.onWishlist`.
    @Test func wishlistOnlyQueryIsOnWishlist() {
        let wanted = Car(castingName: "Toyota Supra", status: .wanted)
        let vm = makeViewModel()
        vm.query = "supra"

        let verdict = vm.verdict(from: [wanted])
        if case let .onWishlist(primary, wantedCastings) = verdict {
            #expect(primary.id == wanted.id)
            #expect(wantedCastings.contains { $0.id == wanted.id })
        } else {
            Issue.record("expected .onWishlist, got \(verdict)")
        }
    }

    // MARK: - Not in collection

    /// A miss that is present in the injected catalog reports `.notInCollection` with a matching hint.
    @Test func missWithCatalogEntryOffersHint() {
        let vm = makeViewModel()
        vm.query = "Toyota Supra"

        let verdict = vm.verdict(from: [])
        if case let .notInCollection(query, hint) = verdict {
            #expect(query == "Toyota Supra")
            #expect(hint?.castingName == "Toyota Supra")
        } else {
            Issue.record("expected .notInCollection with hint, got \(verdict)")
        }
    }

    /// A miss with no catalog entry reports `.notInCollection` with a nil hint.
    @Test func missWithoutCatalogEntryHasNoHint() {
        let vm = makeViewModel()
        vm.query = "Nonexistent Casting Zzz"

        let verdict = vm.verdict(from: [])
        if case let .notInCollection(_, hint) = verdict {
            #expect(hint == nil)
        } else {
            Issue.record("expected .notInCollection with nil hint, got \(verdict)")
        }
    }

    // MARK: - Barcode

    /// Scanning a barcode owned by a car reports `.barcodeHint` containing that car.
    @Test func scannedBarcodeHitsCar() {
        let car = Car(castingName: "Mazda RX-7", status: .owned, barcode: "194735123456")
        let vm = makeViewModel()
        vm.didScan("194735123456")

        let verdict = vm.verdict(from: [car])
        if case let .barcodeHint(matches) = verdict {
            #expect(matches.contains { $0.id == car.id })
        } else {
            Issue.record("expected .barcodeHint, got \(verdict)")
        }
    }

    /// Scanning a barcode no car carries reports `.barcodeMiss`.
    @Test func scannedBarcodeMissReportsBarcode() {
        let car = Car(castingName: "Mazda RX-7", status: .owned, barcode: "194735123456")
        let vm = makeViewModel()
        vm.didScan("000000000000")

        let verdict = vm.verdict(from: [car])
        #expect(verdict == .barcodeMiss(barcode: "000000000000"))
    }
}
