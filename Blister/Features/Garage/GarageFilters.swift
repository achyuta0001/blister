import Foundation
import Observation

/// Filter + sort state for the Garage screen (spec §6.2). Non-trivial enough to warrant an
/// `@Observable` model rather than a fistful of `@State` flags (spec architecture: MV with
/// `@Observable` where state is non-trivial).
///
/// `MainActor`-isolated because it only ever runs alongside SwiftUI view state and reads `Car`
/// (a SwiftData `@Model`, not `Sendable`).
@MainActor
@Observable
final class GarageFilters {
    var brand: Brand?
    var huntStatus: HuntStatus?
    var condition: Condition?
    var series: String?
    var year: Int?
    var sort: GarageSortOption = .recentlyAdded

    /// Whether any filter (not sort) is narrowing the collection.
    var isActive: Bool {
        brand != nil || huntStatus != nil || condition != nil || series != nil || year != nil
    }

    /// Clears every filter chip. Sort is intentionally left untouched.
    func clear() {
        brand = nil
        huntStatus = nil
        condition = nil
        series = nil
        year = nil
    }

    /// True when `car` satisfies every active filter chip.
    func matches(_ car: Car) -> Bool {
        if let brand, car.brand != brand { return false }
        if let huntStatus, car.huntStatus != huntStatus { return false }
        if let condition, car.condition != condition { return false }
        if let series, car.series != series { return false }
        if let year, car.releaseYear != year { return false }
        return true
    }

    /// Applies the active filters and the selected sort to `cars`.
    func apply(to cars: [Car]) -> [Car] {
        sort.sorted(cars.filter(matches))
    }
}
