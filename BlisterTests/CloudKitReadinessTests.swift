import Testing
import Foundation
import SwiftData
@testable import Blister

/// Guards that keep the store CloudKit-syncable (v2.1). CloudKit is not enabled yet, but these
/// assert the two things that would silently break a future flip: a schema that builds, and a
/// full round-trip through an on-disk store with no field loss (the "no destructive migration"
/// proxy). See `docs/superpowers/specs/blister-v2.1-cloudkit-enablement.md`.
struct CloudKitReadinessTests {

    @Test func schemaBuilds() throws {
        // Constructing the schema throws if the model ever adopts something CloudKit rejects.
        _ = Schema([Car.self])
    }

    @Test func fullRoundTripThroughDiskStorePreservesEveryField() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("blister-readiness-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }

        let schema = Schema([Car.self])
        let config = ModelConfiguration(schema: schema, url: url)

        let purchaseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let carID = UUID()

        // Write, then let the container deallocate so the next open reads from disk.
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            let car = Car(
                id: carID,
                castingName: "'67 Camaro",
                brand: .miniGT,
                series: "Car Culture: Japan Historics",
                releaseYear: 1967,
                collectorNumber: "142/250",
                colorway: "Spectraflame Blue",
                wheelType: "RR",
                huntStatus: .superTreasureHunt,
                condition: .openedCard,
                status: .wanted,
                purchasePriceINR: Decimal(string: "1299.50"),
                purchaseDate: purchaseDate,
                purchaseLocation: "Hamleys Phoenix Mall",
                estimatedValueINR: Decimal(string: "3500"),
                notes: "chase piece",
                barcode: "194735000000",
                photoFilenames: ["a.heic", "b.heic"],
                tags: ["camaro", "chevy"]
            )
            context.insert(car)
            try context.save()
        }

        // Reopen fresh and verify nothing was lost or coerced.
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        let idToMatch = carID
        let fetched = try context.fetch(
            FetchDescriptor<Car>(predicate: #Predicate { $0.id == idToMatch })
        )
        #expect(fetched.count == 1)
        let car = try #require(fetched.first)

        #expect(car.castingName == "'67 Camaro")
        #expect(car.brand == .miniGT)                       // enum raw round-trips
        #expect(car.series == "Car Culture: Japan Historics")
        #expect(car.releaseYear == 1967)
        #expect(car.collectorNumber == "142/250")
        #expect(car.colorway == "Spectraflame Blue")
        #expect(car.wheelType == "RR")
        #expect(car.huntStatus == .superTreasureHunt)
        #expect(car.condition == .openedCard)
        #expect(car.status == .wanted)
        #expect(car.purchasePriceINR == Decimal(string: "1299.50"))  // Decimal money, not Double
        #expect(car.purchaseDate == purchaseDate)
        #expect(car.purchaseLocation == "Hamleys Phoenix Mall")
        #expect(car.estimatedValueINR == Decimal(string: "3500"))
        #expect(car.notes == "chase piece")
        #expect(car.barcode == "194735000000")
        #expect(car.photoFilenames == ["a.heic", "b.heic"])          // [String] array round-trips
        #expect(car.tags == ["camaro", "chevy"])
        #expect(!car.searchKey.isEmpty)
    }
}
