import SwiftUI

/// Header strip: collection count, total spend in INR, and the add-a-car action (spec §6.2). The
/// counts reflect the cars currently visible, so the strip stays truthful while filters narrow the
/// grid. Muted and chrome-free (spec §7) — it stands in for a navigation bar, which the Garage hides
/// so the grid starts directly under the status bar.
struct GarageHeader: View {
    let count: Int
    let totalSpend: Decimal
    let onAddCar: () -> Void

    private var countText: String {
        count == 1
            ? String(localized: "1 car")
            : String(localized: "\(count) cars")
    }

    var body: some View {
        HStack(spacing: DesignTokens.spacingM) {
            HStack(alignment: .firstTextBaseline) {
                Text(countText)
                Spacer(minLength: DesignTokens.spacingM)
                Text(CurrencyFormat.inr(totalSpend))
            }
            .font(.footnote)
            .foregroundStyle(DesignTokens.secondaryText)
            .accessibilityElement(children: .combine)

            Button(action: onAddCar) {
                Label(String(localized: "Add Car"), systemImage: "plus")
                    .labelStyle(.iconOnly)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(DesignTokens.primaryText)
                    .frame(
                        minWidth: DesignTokens.minTapTarget,
                        minHeight: DesignTokens.minTapTarget
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, DesignTokens.spacingM)
        .padding(.trailing, DesignTokens.spacingS)
        .padding(.top, DesignTokens.spacingXS)
        .padding(.bottom, DesignTokens.spacingXS)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.background)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    GarageHeader(count: 10, totalSpend: 12450)
        .preferredColorScheme(.dark)
}
