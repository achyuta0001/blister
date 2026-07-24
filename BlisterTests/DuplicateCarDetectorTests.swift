import Testing
import Foundation
@testable import Blister

/// Duplicate-detection predicate for Add Car (spec §6.3). Matching is case/diacritic-insensitive and
/// only owned cars count — wanted cars never do.
struct DuplicateCarDetectorTests {

    @Test func matchesIgnoringCaseAndDiacritics() {
        let existing = Car(castingName: "'67 Camaro", colorway: "Spectraflame Blüe", status: .owned)
        #expect(DuplicateCarDetector.ownedDuplicateExists(
            castingName: "'67 CAMARO",
            colorway: "spectraflame blue",
            in: [existing]
        ))
    }

    @Test func differentColorwayIsNotDuplicate() {
        let existing = Car(castingName: "Datsun 240Z", colorway: "Green", status: .owned)
        #expect(!DuplicateCarDetector.ownedDuplicateExists(
            castingName: "Datsun 240Z",
            colorway: "Red",
            in: [existing]
        ))
    }

    @Test func differentCastingIsNotDuplicate() {
        let existing = Car(castingName: "Datsun 240Z", colorway: "Green", status: .owned)
        #expect(!DuplicateCarDetector.ownedDuplicateExists(
            castingName: "Nissan Skyline",
            colorway: "Green",
            in: [existing]
        ))
    }

    @Test func wantedCarIsNeverDuplicate() {
        let wanted = Car(castingName: "'67 Camaro", colorway: "Spectraflame Blue", status: .wanted)
        #expect(!DuplicateCarDetector.ownedDuplicateExists(
            castingName: "'67 Camaro",
            colorway: "Spectraflame Blue",
            in: [wanted]
        ))
    }

    @Test func missingColorwayOnBothSidesMatches() {
        let existing = Car(castingName: "Mystery Car", colorway: nil, status: .owned)
        #expect(DuplicateCarDetector.ownedDuplicateExists(
            castingName: "mystery car",
            colorway: nil,
            in: [existing]
        ))
    }
}
