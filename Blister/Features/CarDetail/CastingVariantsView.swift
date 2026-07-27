import SwiftUI
import SwiftData

/// Lists the owned cars that share a casting name with the one being viewed (spec §6.4).
/// Reachable from the "you own N variants" link on ``CarDetailView``.
struct CastingVariantsView: View {
    let castingName: String
    let excludingID: UUID
    @Query private var allCars: [Car]

    private let photoStore: PhotoStore = DocumentsPhotoStore.shared

    private var variants: [Car] {
        let key = SearchNormalizer.normalize(castingName)
        guard !key.isEmpty else { return [] }
        return allCars
            .filter { SearchNormalizer.normalize($0.castingName) == key }
            .sorted { $0.dateAdded > $1.dateAdded }
    }

    var body: some View {
        List {
            ForEach(variants) { car in
                NavigationLink {
                    CarDetailView(car: car)
                } label: {
                    VariantRow(car: car, isCurrent: car.id == excludingID)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(DesignTokens.background)
        .navigationTitle(castingName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A single variant row: thumbnail, colorway/series, and price.
private struct VariantRow: View {
    let car: Car
    let isCurrent: Bool

    private let photoStore: PhotoStore = DocumentsPhotoStore.shared

    var body: some View {
        HStack(spacing: DesignTokens.spacingM) {
            thumbnail
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                Text(car.colorway ?? car.brand.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(DesignTokens.primaryText)
                    .lineLimit(1)
                if let series = car.series, !series.isEmpty {
                    Text(series)
                        .font(.caption)
                        .foregroundStyle(DesignTokens.secondaryText)
                        .lineLimit(1)
                }
            }
            Spacer()
            if isCurrent {
                Text(String(localized: "This one"))
                    .font(.caption2)
                    .foregroundStyle(DesignTokens.secondaryText)
            } else {
                Text(CurrencyFormat.inr(car.purchasePriceINR))
                    .font(.caption)
                    .foregroundStyle(DesignTokens.secondaryText)
            }
        }
    }

    @ViewBuilder private var thumbnail: some View {
        if let first = car.photoFilenames.first,
           let image = photoStore.thumbnail(for: first) {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            TypographicPlaceholder(castingName: car.castingName, brand: car.brand)
        }
    }
}
