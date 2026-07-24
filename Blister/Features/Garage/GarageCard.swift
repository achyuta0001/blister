import SwiftUI

/// A single grid cell: square photo (or typographic placeholder) with casting name and colorway
/// left-aligned beneath it (spec §6.2, §7). The photo is the only colour on the card.
struct GarageCard: View {
    let car: Car

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
            ZStack(alignment: .topTrailing) {
                thumbnail
                    .aspectRatio(1, contentMode: .fill)
                    .frame(maxWidth: .infinity)
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
