import SwiftUI
import OSLog

/// The "finish" step shown right after a wishlist car is moved into the garage. The move already
/// happened (one tap on "Found it"), so this sheet does two jobs: it lets the collector **undo** that
/// move if it was a mistake, and it optionally records the purchase details — price, where, and when
/// — matching what the normal Add Car flow captures.
///
/// Dismissing by swipe keeps the car in the garage with whatever was entered (equivalent to "Done").
/// Only the explicit **Undo** control reverts the car to the wishlist.
struct FoundItSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let car: Car

    @State private var price: Decimal?
    @State private var location: String
    @State private var purchaseDate: Date

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Blister",
                               category: "Wishlist")

    init(car: Car) {
        self.car = car
        _price = State(initialValue: car.purchasePriceINR)
        _location = State(initialValue: car.purchaseLocation ?? "")
        // `markFound` stamps today; default the picker to it but let the collector correct it.
        _purchaseDate = State(initialValue: car.purchaseDate ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label {
                        Text(String(localized: "“\(car.castingName)” is now in your garage."))
                            .foregroundStyle(DesignTokens.primaryText)
                    } icon: {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(DesignTokens.accent)
                    }
                }

                Section {
                    TextField(
                        String(localized: "Price paid"),
                        value: $price,
                        format: .currency(code: "INR").precision(.fractionLength(0...2))
                    )
                    .keyboardType(.decimalPad)

                    TextField(String(localized: "Where"), text: $location)
                        .textInputAutocapitalization(.words)

                    DatePicker(
                        String(localized: "When"),
                        selection: $purchaseDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                } header: {
                    Text(String(localized: "Purchase details"))
                } footer: {
                    Text(String(localized: "All optional — add what you have."))
                }
            }
            .scrollContentBackground(.hidden)
            .background(DesignTokens.background)
            .navigationTitle(String(localized: "Found It"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Undo"), role: .destructive) { undoMove() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done")) { saveDetails() }
                }
            }
        }
    }

    /// Keep the car in the garage; persist whatever purchase details were entered.
    private func saveDetails() {
        car.purchasePriceINR = price
        let trimmed = location.trimmingCharacters(in: .whitespacesAndNewlines)
        car.purchaseLocation = trimmed.isEmpty ? nil : trimmed
        car.purchaseDate = purchaseDate
        car.dateModified = Date()
        car.recomputeSearchKey()
        save()
        dismiss()
    }

    /// Revert the move: back to the wishlist, clearing the purchase fields the move stamped.
    private func undoMove() {
        car.status = .wanted
        car.purchaseDate = nil
        car.purchasePriceINR = nil
        car.purchaseLocation = nil
        car.dateModified = Date()
        car.recomputeSearchKey()
        save()
        dismiss()
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            logger.error("Found It sheet save failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
