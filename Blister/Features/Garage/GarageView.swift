import SwiftUI
import SwiftData

/// Garage — a two-column photo grid of owned cars (spec §6.2).
///
/// `@Query` fetches only owned cars, recently-added first. Filter chips (brand / hunt / condition /
/// series / year) and the alternate sorts compose in memory via ``GarageFilters`` because SwiftData
/// predicates can't express the dynamic, collection-derived options. Tapping a card pushes
/// ``CarDetailView``. Cars without a photo fall back to the typographic placeholder (spec §6.2, §7).
struct GarageView: View {
    // Fetch all cars sorted, then filter by status in memory. SwiftData `#Predicate` can't reliably
    // compare a `Codable` enum property (`.rawValue` fails schema validation; `==` matches nothing),
    // and a personal collection is small enough that in-memory filtering is trivial.
    @Query(sort: \Car.dateAdded, order: .reverse) private var allCars: [Car]
    @State private var filters = GarageFilters()
    @State private var isAddingCar = false

    /// Owned cars only (the Garage; wishlist is a separate screen).
    private var owned: [Car] {
        allCars.filter { $0.status == .owned }
    }

    private let columns = [
        GridItem(.flexible(), spacing: DesignTokens.spacingS),
        GridItem(.flexible(), spacing: DesignTokens.spacingS)
    ]

    /// Cars after the active filters and sort are applied.
    private var visibleCars: [Car] {
        filters.apply(to: owned)
    }

    /// Distinct series present in the owned collection, alphabetised.
    private var seriesOptions: [String] {
        Set(owned.compactMap { $0.series }.filter { !$0.isEmpty }).sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
    }

    /// Distinct release years present in the owned collection, newest first.
    private var yearOptions: [Int] {
        Set(owned.compactMap { $0.releaseYear }).sorted(by: >)
    }

    private var totalSpend: Decimal {
        visibleCars.reduce(Decimal.zero) { $0 + ($1.purchasePriceINR ?? 0) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: DesignTokens.spacingS) {
                    ForEach(visibleCars) { car in
                        NavigationLink {
                            CarDetailView(car: car)
                        } label: {
                            GarageCard(car: car)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(DesignTokens.spacingS)
            }
            .background(DesignTokens.background)
            .navigationTitle(String(localized: "Garage"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAddingCar = true
                    } label: {
                        Label(String(localized: "Add Car"), systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAddingCar) {
                AddCarView()
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    GarageHeader(count: visibleCars.count, totalSpend: totalSpend)
                    if !owned.isEmpty {
                        GarageFilterBar(
                            filters: filters,
                            seriesOptions: seriesOptions,
                            yearOptions: yearOptions
                        )
                    }
                }
            }
            .overlay { emptyState }
        }
    }

    @ViewBuilder private var emptyState: some View {
        if owned.isEmpty {
            ContentUnavailableView(
                String(localized: "No cars yet"),
                systemImage: "square.grid.2x2",
                description: Text(String(localized: "Add your first car to get started."))
            )
        } else if visibleCars.isEmpty {
            ContentUnavailableView(
                String(localized: "No matches"),
                systemImage: "line.3.horizontal.decrease.circle",
                description: Text(String(localized: "No cars match the current filters."))
            )
        }
    }
}

#Preview {
    GarageView()
        .modelContainer(.inMemory(seeded: true))
        .preferredColorScheme(.dark)
}
