import Foundation

/// Sample cars for M1 rendering, previews, and manual testing. Not shipped as real user data —
/// the app starts empty for a real user. The `'67 Camaro` fixture below is the one asserted by the
/// search normalisation tests (spec §5), so keep it present.
enum SeedData {
    static func sampleCars() -> [Car] {
        [
            Car(castingName: "'67 Camaro", brand: .hotWheels,
                series: "Car Culture: Japan Historics", releaseYear: 2020,
                collectorNumber: "3/5", colorway: "Spectraflame Blue", wheelType: "RR",
                huntStatus: .superTreasureHunt, condition: .mintOnCard, status: .owned,
                purchasePriceINR: 1200, purchaseLocation: "Hamleys Phoenix Mall",
                estimatedValueINR: 3500, tags: ["camaro", "chevy"]),
            Car(castingName: "Datsun 240Z", brand: .hotWheels,
                series: "Car Culture: Japan Historics", releaseYear: 2019,
                collectorNumber: "1/5", colorway: "Green", wheelType: "RR",
                condition: .mintOnCard, status: .owned, purchasePriceINR: 900,
                purchaseLocation: "Landmark", tags: ["nissan", "datsun"]),
            Car(castingName: "Nissan Skyline GT-R (R34)", brand: .miniGT,
                series: "Mijo Exclusive", releaseYear: 2022, colorway: "Bayside Blue",
                condition: .mintOnCard, status: .owned, purchasePriceINR: 1500,
                purchaseLocation: "Instagram seller", estimatedValueINR: 2200,
                tags: ["skyline", "godzilla"]),
            Car(castingName: "Toyota Supra", brand: .tarmacWorks, releaseYear: 2021,
                colorway: "White", condition: .openedCard, status: .owned,
                purchasePriceINR: 1800, tags: ["supra", "toyota"]),
            Car(castingName: "Mazda RX-7 (FD)", brand: .hotWheels, releaseYear: 2021,
                colorway: "Red", wheelType: "5SP", huntStatus: .treasureHunt,
                condition: .mintOnCard, status: .owned, purchasePriceINR: 250,
                purchaseLocation: "More Supermarket", tags: ["rx7", "mazda"]),
            Car(castingName: "Honda Civic EG", brand: .hotWheels, releaseYear: 2023,
                colorway: "Black", condition: .mintOnCard, status: .owned,
                purchasePriceINR: 130, purchaseLocation: "Reliance Smart"),
            Car(castingName: "Volkswagen Golf MK2", brand: .matchbox, releaseYear: 2020,
                colorway: "Silver", condition: .loose, status: .owned,
                purchasePriceINR: 110, tags: ["vw", "golf"]),
            Car(castingName: "Lancia Delta Integrale", brand: .miniGT, releaseYear: 2023,
                colorway: "Martini Racing", condition: .mintOnCard, status: .owned,
                purchasePriceINR: 1600, estimatedValueINR: 1900, tags: ["lancia", "rally"]),
            Car(castingName: "Porsche 911 GT3 RS", brand: .majorette, releaseYear: 2022,
                colorway: "Yellow", condition: .openedCard, status: .owned,
                purchasePriceINR: 400, tags: ["porsche"]),
            Car(castingName: "Toyota AE86 Trueno", brand: .tomica, releaseYear: 2021,
                colorway: "Panda", condition: .mintOnCard, status: .owned,
                purchasePriceINR: 700, tags: ["ae86", "initiald"]),
            // Wishlist entries (status == .wanted)
            Car(castingName: "Nissan Fairlady Z (Z432)", brand: .hotWheels,
                series: "Car Culture", colorway: "Orange", status: .wanted,
                tags: ["nissan"]),
            Car(castingName: "Mitsubishi Lancer Evolution", brand: .tarmacWorks,
                colorway: "Rally White", status: .wanted, tags: ["evo", "rally"]),
            Car(castingName: "BMW M3 E30", brand: .miniGT, colorway: "Alpine White",
                status: .wanted, estimatedValueINR: 1800, tags: ["bmw"]),
        ]
    }
}
