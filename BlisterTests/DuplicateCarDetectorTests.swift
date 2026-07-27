import Testing
import Foundation
@testable import Blister

/// Duplicate-detection predicate for Add Car (spec §6.3). Matching is case/diacritic-insensitive and
/// scoped to the list being added to: the garage check ignores wishlist cars, the wishlist check
/// ignores garage cars.
struct DuplicateCarDetectorTests {

    // MARK: - Garage duplicates

    @Test func matchesIgnoringCaseAndDiacritics() {
        let existing = Car(castingName: "'67 Camaro", colorway: "Spectraflame Blüe", status: .owned)
        #expect(DuplicateCarDetector.duplicateExists(
            castingName: "'67 CAMARO",
            colorway: "spectraflame blue",
            status: .owned,
            in: [existing]
        ))
    }

    @Test func differentColorwayIsNotDuplicate() {
        let existing = Car(castingName: "Datsun 240Z", colorway: "Green", status: .owned)
        #expect(!DuplicateCarDetector.duplicateExists(
            castingName: "Datsun 240Z",
            colorway: "Red",
            status: .owned,
            in: [existing]
        ))
    }

    @Test func differentCastingIsNotDuplicate() {
        let existing = Car(castingName: "Datsun 240Z", colorway: "Green", status: .owned)
        #expect(!DuplicateCarDetector.duplicateExists(
            castingName: "Nissan Skyline",
            colorway: "Green",
            status: .owned,
            in: [existing]
        ))
    }

    @Test func wantedCarIsNeverAGarageDuplicate() {
        let wanted = Car(castingName: "'67 Camaro", colorway: "Spectraflame Blue", status: .wanted)
        #expect(!DuplicateCarDetector.duplicateExists(
            castingName: "'67 Camaro",
            colorway: "Spectraflame Blue",
            status: .owned,
            in: [wanted]
        ))
    }

    @Test func missingColorwayOnBothSidesMatches() {
        let existing = Car(castingName: "Mystery Car", colorway: nil, status: .owned)
        #expect(DuplicateCarDetector.duplicateExists(
            castingName: "mystery car",
            colorway: nil,
            status: .owned,
            in: [existing]
        ))
    }

    // MARK: - Wishlist duplicates
    //
    // Adding the same car to the wishlist twice is always a mistake — a wishlist row means "find me
    // one of these", and you only need to be told once. Nothing warned about it before: the check was
    // hardwired to `.owned`, which by design never matches a wanted car.

    @Test func wantedDuplicateIsDetected() {
        let existing = Car(castingName: "'67 Camaro", colorway: "Spectraflame Blue", status: .wanted)
        #expect(DuplicateCarDetector.duplicateExists(
            castingName: "'67 Camaro",
            colorway: "Spectraflame Blue",
            status: .wanted,
            in: [existing]
        ))
    }

    @Test func wantedDuplicateIgnoresCaseAndDiacritics() {
        let existing = Car(castingName: "'67 Camaro", colorway: "Spectraflame Blüe", status: .wanted)
        #expect(DuplicateCarDetector.duplicateExists(
            castingName: "'67 CAMARO",
            colorway: "spectraflame blue",
            status: .wanted,
            in: [existing]
        ))
    }

    @Test func wantedDuplicateNeedsTheSameColorway() {
        let existing = Car(castingName: "Datsun 240Z", colorway: "Green", status: .wanted)
        #expect(!DuplicateCarDetector.duplicateExists(
            castingName: "Datsun 240Z",
            colorway: "Red",
            status: .wanted,
            in: [existing]
        ))
    }

    /// The two lists stay independent in both directions: already owning one is no reason to refuse
    /// wishlisting another (collectors buy spares and chase upgrades)…
    @Test func ownedCarIsNotAWishlistDuplicate() {
        let owned = Car(castingName: "'67 Camaro", colorway: "Spectraflame Blue", status: .owned)
        #expect(!DuplicateCarDetector.duplicateExists(
            castingName: "'67 Camaro",
            colorway: "Spectraflame Blue",
            status: .wanted,
            in: [owned]
        ))
    }

    /// …and one mixed collection, checked from both sides, since this is the single entry point the
    /// view calls with whichever list the form is pointed at.
    @Test func duplicateExistsIsScopedToTheListBeingAddedTo() {
        let cars = [
            Car(castingName: "'67 Camaro", colorway: "Spectraflame Blue", status: .owned),
            Car(castingName: "Datsun 240Z", colorway: "Green", status: .wanted)
        ]

        #expect(DuplicateCarDetector.duplicateExists(
            castingName: "'67 Camaro", colorway: "Spectraflame Blue", status: .owned, in: cars
        ))
        #expect(!DuplicateCarDetector.duplicateExists(
            castingName: "'67 Camaro", colorway: "Spectraflame Blue", status: .wanted, in: cars
        ))
        #expect(DuplicateCarDetector.duplicateExists(
            castingName: "Datsun 240Z", colorway: "Green", status: .wanted, in: cars
        ))
        #expect(!DuplicateCarDetector.duplicateExists(
            castingName: "Datsun 240Z", colorway: "Green", status: .owned, in: cars
        ))
    }

    /// Batch entry: "Save and add another" clears the casting name, so the warning can only come back
    /// once the collector retypes the same car — which is exactly the case it exists for.
    @MainActor
    @Test func aSecondIdenticalWishlistEntryWarns() {
        let model = AddCarModel(status: .wanted)
        model.castingName = "'67 Camaro"
        model.colorway = "Spectraflame Blue"
        let saved = model.makeCar(photoFilenames: [])

        model.reset()
        #expect(!DuplicateCarDetector.duplicateExists(
            castingName: model.castingName, colorway: model.colorway, status: model.status, in: [saved]
        ))

        model.castingName = "'67 Camaro"
        model.colorway = "Spectraflame Blue"
        #expect(DuplicateCarDetector.duplicateExists(
            castingName: model.castingName, colorway: model.colorway, status: model.status, in: [saved]
        ))
    }
}
