import SwiftUI
import SwiftData
import OSLog

/// Wishlist — the same two-column grid as Garage, filtered to `status == .wanted` (spec §6.5).
///
/// Each card's primary action is **"Found it"**: a single tap flips the car to `.owned` (moving it
/// out of the wishlist and into the Garage per spec §4) and then offers an optional price-paid
/// prompt. The flip happens immediately so the move feels like one tap; the price is optional.
struct WishlistView: View {
    @Environment(\.modelContext) private var modelContext
    // Fetch all cars sorted, then filter to wanted in memory — SwiftData `#Predicate` can't reliably
    // compare a `Codable` enum property. See the note in `GarageView`.
    @Query(sort: \Car.dateAdded, order: .reverse) private var allCars: [Car]

    /// Wishlist cars only.
    private var wanted: [Car] {
        allCars.filter { $0.status == .wanted }
    }

    /// The car whose "Found it" price prompt is currently shown. Set after the status flip so the
    /// card has already left the grid — the sheet only collects the optional price.
    @State private var foundCar: Car?

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Blister",
                               category: "Wishlist")

    private let columns = [
        GridItem(.flexible(), spacing: DesignTokens.spacingS),
        GridItem(.flexible(), spacing: DesignTokens.spacingS)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: DesignTokens.spacingS) {
                    ForEach(wanted) { car in
                        WishlistCard(car: car) { markFound(car) }
                    }
                }
                .padding(DesignTokens.spacingS)
            }
            .background(DesignTokens.background)
            .navigationTitle(String(localized: "Wishlist"))
            .navigationBarTitleDisplayMode(.large)
            .overlay {
                if wanted.isEmpty {
                    ContentUnavailableView(
                        String(localized: "Nothing on the wishlist"),
                        systemImage: "star",
                        description: Text(String(localized: "Cars you're hunting for will show up here. Tap \u{201C}Found it\u{201D} to move one into your garage."))
                    )
                }
            }
            .sheet(item: $foundCar) { car in
                FoundItSheet(car: car)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    /// Single-tap wishlist → garage move (spec §4): flip to `.owned`, stamp the purchase date, save,
    /// then present the optional price prompt.
    private func markFound(_ car: Car) {
        car.status = .owned
        car.purchaseDate = Date()
        car.dateModified = Date()
        car.recomputeSearchKey()
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to mark car as found: \(error.localizedDescription, privacy: .public)")
        }
        foundCar = car
    }
}

#Preview {
    WishlistView()
        .modelContainer(.inMemory(seeded: true))
        .preferredColorScheme(.dark)
}
