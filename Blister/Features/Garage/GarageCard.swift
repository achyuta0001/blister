import SwiftUI

/// A single grid cell: square photo (or typographic placeholder) with casting name and colorway
/// left-aligned beneath it (spec §6.2, §7). The photo is the only colour on the card.
struct GarageCard: View {
    let car: Car

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
            ZStack(alignment: .topTrailing) {
                // The square cell is carved out of an empty `Color`, not out of the photo. Putting
                // `.aspectRatio(1, …)` on the image itself hands a *resizable* image an explicit
                // ratio, which overrides the picture's own and **stretches** it into the square —
                // a portrait card came out horizontally fat. Sizing a shape and overlaying the
                // photo keeps the cell square while the photo crops (see `thumbnail`).
                Color.clear
                    .aspectRatio(1, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .overlay { thumbnail }
                    .clipped()
                if let badge = car.huntStatus.badge {
                    Text(badge)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(DesignTokens.accent, in: Capsule())
                        .foregroundStyle(DesignTokens.background)
                        .padding(DesignTokens.spacingXS)
                }
            }
            Text(car.castingName)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(DesignTokens.primaryText)
                .lineLimit(1)
            if let colorway = car.colorway, !colorway.isEmpty {
                Text(colorway)
                    .font(.caption)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabel))
    }

    /// Fills the square cell it is overlaid on. `.scaledToFill()` takes **no** ratio argument, so the
    /// photo keeps its own aspect and the overflow is cropped by the cell's `.clipped()`. Stored
    /// thumbnails are no longer square — a cleaned card saves at the card's own ~0.62 aspect — so
    /// this is the difference between a cropped card and a squashed one.
    @ViewBuilder private var thumbnail: some View {
        if let first = car.photoFilenames.first,
           let image = DocumentsPhotoStore.shared.thumbnail(for: first) {
            Image(uiImage: image)
                .resizable()
        } else {
            TypographicPlaceholder(castingName: car.castingName, brand: car.brand)
        }
    }

    private var accessibilityLabel: String {
        var parts: [String] = [car.castingName, car.brand.displayName]
        if let colorway = car.colorway, !colorway.isEmpty { parts.append(colorway) }
        if car.huntStatus != .none { parts.append(car.huntStatus.displayName) }
        return parts.joined(separator: ", ")
    }
}

#Preview {
    GarageCard(car: SeedData.sampleCars()[0])
        .frame(width: 180)
        .padding()
        .background(DesignTokens.background)
        .preferredColorScheme(.dark)
}
