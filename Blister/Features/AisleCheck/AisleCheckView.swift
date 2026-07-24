import SwiftUI
import SwiftData
import os

/// Aisle Check — the primary screen (spec §6.1). **Owned by Agent 4.**
///
/// The one moment the app exists for: standing in a shop aisle, holding a car, needing to know in
/// under three seconds whether it is already owned. Optimised for one-handed use in bad lighting —
/// the search field is pinned at the bottom within thumb reach and autofocused, results are live, and
/// the verdict is set in giant type.
struct AisleCheckView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Car.dateAdded, order: .reverse) private var allCars: [Car]

    @State private var model: AisleCheckViewModel
    @State private var isShowingScanner = false
    @State private var isAddingCar = false
    @FocusState private var searchFocused: Bool

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Blister",
        category: "AisleCheck"
    )

    init(searchEngine: any SearchEngine = LiveSearchEngine()) {
        _model = State(initialValue: AisleCheckViewModel(searchEngine: searchEngine))
    }

    private var verdict: AisleVerdict {
        model.verdict(from: allCars)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.background.ignoresSafeArea()
                VerdictDisplay(
                    verdict: verdict,
                    onAddOwned: { add(status: .owned) },
                    onAddWanted: { add(status: .wanted) },
                    onClearScan: { model.clearScan() }
                )
            }
            .overlay(alignment: .topTrailing) {
                addButton
            }
            .safeAreaInset(edge: .bottom) {
                searchBar
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(DesignTokens.accent)
        .onAppear { searchFocused = true }
        .sheet(isPresented: $isShowingScanner) {
            scannerSheet
        }
        .sheet(isPresented: $isAddingCar) {
            AddCarView()
        }
    }

    // MARK: - Add button (full capture flow, mirrors Garage)

    private var addButton: some View {
        Button {
            searchFocused = false
            isAddingCar = true
        } label: {
            Image(systemName: "plus")
                .font(.title2)
                .foregroundStyle(DesignTokens.primaryText)
                .frame(width: DesignTokens.minTapTarget, height: DesignTokens.minTapTarget)
                .overlay(Circle().stroke(DesignTokens.hairline, lineWidth: 1))
        }
        .accessibilityLabel(Text(String(localized: "Add Car")))
        .padding(.trailing, DesignTokens.spacingM)
        .padding(.top, DesignTokens.spacingS)
    }

    // MARK: - Search bar (bottom, thumb reach)

    private var searchBar: some View {
        HStack(spacing: DesignTokens.spacingS) {
            HStack(spacing: DesignTokens.spacingS) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DesignTokens.secondaryText)
                TextField(
                    String(localized: "Search your collection"),
                    text: $model.query
                )
                .focused($searchFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .foregroundStyle(DesignTokens.primaryText)
                .onChange(of: model.query) { _, newValue in
                    // Typing overrides a stale barcode scan.
                    if !newValue.isEmpty { model.clearScan() }
                }
                if !model.query.isEmpty {
                    Button {
                        model.query = ""
                        searchFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(DesignTokens.secondaryText)
                    }
                    .frame(width: DesignTokens.minTapTarget, height: DesignTokens.minTapTarget)
                    .accessibilityLabel(Text(String(localized: "Clear search")))
                }
            }
            .padding(.horizontal, DesignTokens.spacingM)
            .frame(minHeight: DesignTokens.minTapTarget)
            .background(
                Capsule().fill(DesignTokens.background)
            )
            .overlay(Capsule().stroke(DesignTokens.hairline, lineWidth: 1))

            if BarcodeScannerView.isSupported {
                Button {
                    searchFocused = false
                    isShowingScanner = true
                } label: {
                    Image(systemName: "barcode.viewfinder")
                        .font(.title2)
                        .foregroundStyle(DesignTokens.primaryText)
                        .frame(width: DesignTokens.minTapTarget, height: DesignTokens.minTapTarget)
                        .overlay(Circle().stroke(DesignTokens.hairline, lineWidth: 1))
                }
                .accessibilityLabel(Text(String(localized: "Scan barcode")))
            }
        }
        .padding(.horizontal, DesignTokens.spacingM)
        .padding(.top, DesignTokens.spacingS)
        .padding(.bottom, DesignTokens.spacingS)
        .background(.ultraThinMaterial)
    }

    // MARK: - Scanner sheet

    @ViewBuilder private var scannerSheet: some View {
        NavigationStack {
            BarcodeScannerView { code in
                model.didScan(code)
                isShowingScanner = false
            }
            .ignoresSafeArea()
            .navigationTitle(String(localized: "Scan Barcode"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { isShowingScanner = false }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Text(String(localized: "A barcode is a hint, not proof — assortments share barcodes."))
                    .font(.footnote)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(DesignTokens.spacingM)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
    }

    // MARK: - Mutations

    /// Insert a new car prefilled from the current query (spec §6.1). `recomputeSearchKey()` is called
    /// explicitly before saving so the denormalised key is current (spec §5).
    private func add(status: CollectionStatus) {
        let name = model.trimmedQuery
        let car = Car(
            castingName: name,
            status: status,
            barcode: model.scannedBarcode
        )
        car.recomputeSearchKey()
        modelContext.insert(car)
        do {
            try modelContext.save()
            logger.info("Added car to \(status.rawValue, privacy: .public): \(name, privacy: .public)")
        } catch {
            logger.error("Failed to save new car: \(error.localizedDescription, privacy: .public)")
        }
        // Reset so the aisle check is ready for the next car; the just-added car now reads as owned.
        model.clearScan()
        model.query = name
        searchFocused = true
    }
}

#Preview {
    AisleCheckView()
        .modelContainer(.inMemory(seeded: true))
        .preferredColorScheme(.dark)
}
