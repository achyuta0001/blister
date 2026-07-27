import SwiftUI
import SwiftData
import os

/// Car Detail (spec §6.4). **Owned by Agent 3.**
///
/// Swipeable photos, all fields, inline edit, and delete-with-confirmation. When other owned cars
/// share the normalised casting name, a link surfaces the "you own N variants" set.
struct CarDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let car: Car
    @Query private var allCars: [Car]

    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var studioPhoto: StudioPhoto?

    private let photoStore: PhotoStore = DocumentsPhotoStore.shared
    private let logger = Logger(subsystem: "app.blister", category: "CarDetail")

    /// How many of this casting the collector owns, this one included. Owned-only — see
    /// ``CastingVariants``, which ``CastingVariantsView`` shares so the count and the list agree.
    private var ownedVariantCount: Int {
        CastingVariants.ownedCount(including: car, in: allCars)
    }

    var body: some View {
        List {
            Section {
                photoCarousel
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            // Shown from two, so the plural in the label is always right.
            if ownedVariantCount > 1 {
                Section {
                    NavigationLink {
                        CastingVariantsView(castingName: car.castingName, excludingID: car.id)
                    } label: {
                        Label(
                            String(localized: "You own \(ownedVariantCount) variants of this casting"),
                            systemImage: "square.stack.3d.up"
                        )
                    }
                }
            }

            Section {
                LabeledContent(String(localized: "Casting"), value: car.castingName)
                LabeledContent(String(localized: "Brand"), value: car.brand.displayName)
                if let series = car.series, !series.isEmpty {
                    LabeledContent(String(localized: "Series"), value: series)
                }
                if let colorway = car.colorway, !colorway.isEmpty {
                    LabeledContent(String(localized: "Colorway"), value: colorway)
                }
                if let year = car.releaseYear {
                    LabeledContent(String(localized: "Year"), value: String(year))
                }
                LabeledContent(String(localized: "Condition"), value: car.condition.displayName)
                if car.huntStatus != .none {
                    LabeledContent(String(localized: "Hunt"), value: car.huntStatus.displayName)
                }
            }

            Section(String(localized: "Purchase")) {
                LabeledContent(String(localized: "Paid"), value: CurrencyFormat.inr(car.purchasePriceINR))
                if let location = car.purchaseLocation, !location.isEmpty {
                    LabeledContent(String(localized: "Where"), value: location)
                }
            }

            if let notes = car.notes, !notes.isEmpty {
                Section(String(localized: "Notes")) {
                    Text(notes)
                }
            }

            Section {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label(String(localized: "Delete Car"), systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(DesignTokens.background)
        .navigationTitle(car.castingName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(String(localized: "Edit")) { showEdit = true }
            }
        }
        .sheet(isPresented: $showEdit) {
            CarEditView(car: car)
        }
        .fullScreenCover(item: $studioPhoto) { photo in
            StudioView(image: photo.image)
        }
        .confirmationDialog(
            String(localized: "Delete this car?"),
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Delete"), role: .destructive) { deleteCar() }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "This permanently removes the car and its photos."))
        }
    }

    // MARK: Photos

    @ViewBuilder private var photoCarousel: some View {
        TabView {
            if car.photoFilenames.isEmpty {
                TypographicPlaceholder(castingName: car.castingName, brand: car.brand)
            } else {
                ForEach(car.photoFilenames, id: \.self) { filename in
                    photoPage(filename)
                }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: car.photoFilenames.count > 1 ? .automatic : .never))
        .frame(height: 320)
    }

    @ViewBuilder private func photoPage(_ filename: String) -> some View {
        if let image = photoStore.fullImage(for: filename) {
            // Real photos get the tactile tilt + sheen, and tap through to the 3D studio.
            TiltSheenContainer {
                studioPhoto = StudioPhoto(image: image)
            } content: {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
        } else {
            TypographicPlaceholder(castingName: car.castingName, brand: car.brand)
        }
    }

    /// Identifiable wrapper so a `UIImage` can drive `.fullScreenCover(item:)`.
    private struct StudioPhoto: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    // MARK: Actions

    private func deleteCar() {
        for filename in car.photoFilenames {
            do {
                try photoStore.delete(filename)
            } catch {
                logger.error("Photo delete failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        modelContext.delete(car)
        do {
            try modelContext.save()
        } catch {
            logger.error("Car delete save failed: \(error.localizedDescription, privacy: .public)")
        }
        dismiss()
    }
}

#Preview {
    NavigationStack {
        CarDetailView(car: SeedData.sampleCars()[0])
    }
    .modelContainer(.inMemory(seeded: true))
    .preferredColorScheme(.dark)
}
