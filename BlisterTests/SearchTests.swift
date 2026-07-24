import Testing
import Foundation
@testable import Blister

/// Search normalisation, ranking, and performance suite (spec §5).
struct SearchTests {

    private let engine = LiveSearchEngine()

    // MARK: - Normalisation fixtures

    @Test func allSixQueriesMatchTheCamaroFixture() {
        let camaro = Car(castingName: "'67 Camaro", series: "Car Culture: Japan Historics")
        let decoy = Car(castingName: "Datsun 240Z", series: "Boulevard")
        let cars = [camaro, decoy]

        let queries = [
            "67 camaro",
            "'67 camaro",
            "camaro 67",
            "1967 camaro",
            "camaro",
            "japan historics",
        ]

        for query in queries {
            let results = engine.search(query, in: cars)
            #expect(
                results.contains { $0.id == camaro.id },
                "expected query \"\(query)\" to match the '67 Camaro"
            )
        }
    }

    @Test func yearConventionIsBidirectional() {
        // A car whose casting name uses the full four-digit year is still found by the two-digit form.
        let mustang = Car(castingName: "1969 Mustang")
        let results = engine.search("69 mustang", in: [mustang])
        #expect(results.first?.id == mustang.id)
    }

    @Test func emptyQueryReturnsInputUnchanged() {
        let cars = [Car(castingName: "A"), Car(castingName: "B")]
        #expect(engine.search("   ", in: cars).count == cars.count)
    }

    // MARK: - Ranking order

    @Test func exactBeatsPrefix() {
        let exact = Car(castingName: "Camaro")
        let prefix = Car(castingName: "Camaro SS")
        let results = engine.search("camaro", in: [prefix, exact])
        #expect(results.first?.id == exact.id)
    }

    @Test func prefixBeatsTokenSubset() {
        let prefix = Car(castingName: "Mustang GT")
        let subset = Car(castingName: "Boss", series: "Mustang Mania")
        let results = engine.search("mustang", in: [subset, prefix])
        #expect(results.first?.id == prefix.id)
    }

    @Test func tokenSubsetBeatsFuzzy() {
        let subset = Car(castingName: "Skyline", tags: ["camaro"])
        let fuzzy = Car(castingName: "Camoro") // one-character typo of "camaro"
        let results = engine.search("camaro", in: [fuzzy, subset])
        #expect(results.first?.id == subset.id)
    }

    @Test func fuzzyToleratesTypoWithinDistanceTwo() {
        let car = Car(castingName: "Lamborghini")
        let results = engine.search("lambogini", in: [car]) // two edits away
        #expect(results.first?.id == car.id)
    }

    // MARK: - Performance

    @Test func searchOverFiveThousandCarsIsUnderFiftyMilliseconds() {
        var cars: [Car] = []
        cars.reserveCapacity(5_000)
        for i in 0..<5_000 {
            cars.append(
                Car(
                    castingName: "Casting \(i) Camaro",
                    series: "Series \(i % 25)",
                    colorway: "Colorway \(i % 40)",
                    tags: ["tag\(i % 10)"]
                )
            )
        }

        let clock = ContinuousClock()
        let elapsed = clock.measure {
            _ = engine.search("camaro", in: cars)
        }

        #expect(elapsed < .milliseconds(50), "search took \(elapsed)")
    }
}
