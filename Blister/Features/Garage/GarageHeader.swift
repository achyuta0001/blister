import SwiftUI

/// Header strip: collection count and total spend in INR (spec §6.2). Reflects the cars currently
/// visible, so it stays truthful while filters narrow the grid. Left-aligned, muted, no chrome
/// (spec §7).
struct GarageHeader: View {
    let count: Int
    let totalSpend: Decimal

    private var countText: String {
        count == 1
            ? String(localized: "1 car")
            : String(localized: "\(count) cars")
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(countText)
            Spacer(minLength: DesignTokens.spacingM)
            Text(CurrencyFormat.inr(totalSpend))
        }
        .font(.footnote)
        .foregroundStyle(DesignTokens.secondaryText)
        .padding(.horizontal, DesignTokens.spacingM)
        .padding(.top, DesignTokens.spacingS)
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
