import SwiftUI

/// A single wishlist grid cell: square photo (or typographic placeholder), casting name, colorway,
/// and a **"Found it"** action. Tapping the artwork opens the detail view; tapping "Found it"
/// invokes `onFound` — the single tap that moves the car into the garage (spec §6.5).
///
/// The action is a ghost (outline) button rather than a filled one so a long wishlist doesn't become
/// a wall of accent bars — the accent flashes only on press, keeping the car photos as the only
/// colour in the grid (spec §7).
struct WishlistCard: View {
    let car: Car
    let onFound: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
            NavigationLink { CarDetailView(car: car) } label: {
                VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                    // Square cell from an empty `Color`, photo overlaid — same reasoning as
                    // ``GarageCard``: an explicit `.aspectRatio(1, …)` on a resizable image
                    // overrides the picture's own ratio and stretches it instead of cropping.
                    Color.clear
                        .aspectRatio(1, contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .overlay { thumbnail }
                        .clipped()
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
            }
            .buttonStyle(.plain)

            Button(action: onFound) {
                Text(String(localized: "Found it"))
            }
            .buttonStyle(GhostActionButtonStyle())
            .accessibilityHint(Text(String(localized: "Moves this car into your garage")))
        }
    }

    /// Fills the square cell it is overlaid on, cropping rather than stretching — `.scaledToFill()`
    /// takes no ratio argument, so the photo keeps its own (see ``GarageCard``).
    @ViewBuilder private var thumbnail: some View {
        if let first = car.photoFilenames.first,
           let image = DocumentsPhotoStore.shared.thumbnail(for: first) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            TypographicPlaceholder(castingName: car.castingName, brand: car.brand)
        }
    }
}

/// Outline button whose accent appears only while pressed — keeps the resting grid free of accent
/// bars (spec §7) while making the tap feel alive at the moment of contact.
private struct GhostActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let active = configuration.isPressed
        return configuration.label
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: DesignTokens.minTapTarget)
            .foregroundStyle(active ? DesignTokens.accent : DesignTokens.primaryText)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(active ? DesignTokens.accent.opacity(0.12) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(active ? DesignTokens.accent : DesignTokens.hairline, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .animation(.easeOut(duration: 0.12), value: active)
    }
}
