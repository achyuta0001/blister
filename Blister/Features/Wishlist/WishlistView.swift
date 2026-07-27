import SwiftUI
import SwiftData
import OSLog

/// Wishlist — the same two-column grid as Garage, filtered to `status == .wanted` (spec §6.5).
///
/// Each card's primary action is **"Found it"**: a single tap flips the car to `.owned` (moving it
/// out of the wishlist and into the Garage per spec §4) and then offers an optional price-paid
/// prompt. The flip happens immediately so the move feels like one tap; the price is optional.
///
/// The "+" in the toolbar opens the full Add Car form pre-set to `.wanted`, so a car can be put on
/// the wishlist directly rather than only via an Aisle Check miss.
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

    /// Non-nil when the "Found it" save failed, so the user is told rather than the failure being
    /// swallowed.
    @State private var saveError: ErrorAlert?

    /// Drives the Add Car sheet behind the "+" toolbar button.
    @State private var isAddingCar = false

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
            // Unlike Garage and Aisle Check, this screen keeps its navigation bar, so the "+" belongs
            // in the toolbar rather than in a bespoke header strip.
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAddingCar = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(Text(String(localized: "Add to wishlist")))
                }
            }
            .overlay {
                if wanted.isEmpty {
                    ContentUnavailableView(
                        String(localized: "Nothing on the wishlist"),
                        systemImage: "star",
                        description: Text(String(localized: "Tap + to add a car you’re hunting for. When you track it down, \u{201C}Found it\u{201D} moves it into your garage."))
                    )
                }
            }
            .sheet(isPresented: $isAddingCar) {
                AddCarView(initialStatus: .wanted)
            }
            .sheet(item: $foundCar) { car in
                FoundItSheet(car: car)
                    .presentationDetents([.medium, .large])
            }
            .errorAlert($saveError)
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
            saveError = ErrorAlert(
                message: String(localized: "This car couldn’t be moved to your garage. Please try again.")
            )
            return
        }
        foundCar = car
    }
}

#Preview {
    WishlistView()
        .modelContainer(.inMemory(seeded: true))
        .preferredColorScheme(.dark)
}
