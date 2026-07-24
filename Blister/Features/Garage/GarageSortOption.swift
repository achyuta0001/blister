import Foundation

/// Sort options for the Garage grid (spec §6.2). Applied in memory so it can compose with the
/// dynamic filter chips, which `@Query` cannot express on its own.
enum GarageSortOption: String, CaseIterable, Identifiable {
    case recentlyAdded
    case castingName
    case year
    case value

    var id: String { rawValue }

    var label: String {
        switch self {
        case .recentlyAdded: return String(localized: "Recently Added")
        case .castingName:   return String(localized: "Casting Name")
        case .year:          return String(localized: "Year")
        case .value:         return String(localized: "Value")
        }
    }

    /// Returns `cars` ordered for this option. Stable, so cars missing the sort key keep their
    /// relative (recently-added) order rather than jumping around.
    func sorted(_ cars: [Car]) -> [Car] {
        switch self {
        case .recentlyAdded:
            return cars.sorted { $0.dateAdded > $1.dateAdded }
        case .castingName:
            return cars.sorted {
                $0.castingName.localizedStandardCompare($1.castingName) == .orderedAscending
            }
        case .year:
            // Newest first; unknown years sink to the bottom.
            return cars.sorted { ($0.releaseYear ?? .min) > ($1.releaseYear ?? .min) }
        case .value:
            // Most valuable first; unknown values sink to the bottom.
            return cars.sorted { ($0.estimatedValueINR ?? 0) > ($1.estimatedValueINR ?? 0) }
        }
    }
}
