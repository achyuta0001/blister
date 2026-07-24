import Testing
import Foundation
@testable import Blister

/// JSON export/import archive (spec §6.6): encode/decode round trip and last-writer-wins merge policy.
struct CollectionArchiveTests {

    @Test func roundTripPreservesEveryField() throws {
        let car = Car(
            castingName: "'67 Camaro",
            brand: .hotWheels,
            series: "Car Culture",
            releaseYear: 2021,
            collectorNumber: "142/250",
            colorway: "Spectraflame Blue",
            wheelType: "RR",
            huntStatus: .superTreasureHunt,
            condition: .mintOnCard,
            status: .owned,
            purchasePriceINR: Decimal(string: "1299.50"),
            purchaseLocation: "Hamleys",
            estimatedValueINR: Decimal(string: "4500"),
            notes: "grail",
            barcode: "887961",
            photoFilenames: ["a.jpg"],
            tags: ["jdm", "blue"]
        )

        let data = try CollectionArchive(cars: [car]).jsonData()
        let decoded = try CollectionArchive.decode(from: data)

        #expect(decoded.version == CollectionArchive.currentVersion)
        #expect(decoded.cars.count == 1)
        let record = try #require(decoded.cars.first)
        #expect(record.id == car.id)
        #expect(record.castingName == "'67 Camaro")
        #expect(record.brand == "hotWheels")
        #expect(record.series == "Car Culture")
        #expect(record.releaseYear == 2021)
        #expect(record.colorway == "Spectraflame Blue")
        #expect(record.huntStatus == "superTreasureHunt")
        #expect(record.status == "owned")
        // Money survives exactly as Decimal, not a lossy Double.
        #expect(record.purchasePriceINR == Decimal(string: "1299.50"))
        #expect(record.estimatedValueINR == Decimal(string: "4500"))
        #expect(record.photoFilenames == ["a.jpg"])
        #expect(record.tags == ["jdm", "blue"])
    }

    @Test func makeCarRebuildsEnumsAndSearchKey() throws {
        let original = Car(castingName: "Datsun 240Z", colorway: "Green", huntStatus: .treasureHunt)
        let data = try CollectionArchive(cars: [original]).jsonData()
        let decoded = try CollectionArchive.decode(from: data)
        let rebuilt = try #require(decoded.cars.first).makeCar()

        #expect(rebuilt.castingName == "Datsun 240Z")
        #expect(rebuilt.huntStatus == .treasureHunt)
        #expect(rebuilt.searchKey.contains("datsun"))
    }

    @Test func lastWriterWins() {
        let older = Date(timeIntervalSince1970: 1_000)
        let newer = Date(timeIntervalSince1970: 2_000)
        let incoming = CarRecord(car: Car(castingName: "x", dateModified: newer))

        #expect(CollectionArchive.shouldOverwrite(incoming: incoming, existingDateModified: older))
        #expect(!CollectionArchive.shouldOverwrite(incoming: incoming, existingDateModified: Date(timeIntervalSince1970: 3_000)))
        // Ties overwrite (>=), keeping the merge deterministic.
        #expect(CollectionArchive.shouldOverwrite(incoming: incoming, existingDateModified: newer))
    }
}
