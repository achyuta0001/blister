import SwiftUI

/// The pill label used by every Garage filter/sort control. Monochrome by design: selection is
/// shown by inverting fill, never by colour — the single accent is reserved for hunt status
/// (spec §7). Sits inside a 44pt tap target supplied by its enclosing `Menu` (spec §7 a11y).
struct GarageChipLabel: View {
    let title: String
    var systemImage: String = "chevron.down"
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: DesignTokens.spacingXS) {
            Text(title)
                .lineLimit(1)
            Image(systemName: systemImage)
                .font(.caption2.weight(.semibold))
                .imageScale(.small)
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(isSelected ? DesignTokens.background : DesignTokens.primaryText)
        .padding(.horizontal, DesignTokens.spacingM)
        .padding(.vertical, DesignTokens.spacingS)
        .background {
            if isSelected {
                Capsule().fill(DesignTokens.primaryText)
            } else {
                Capsule().stroke(DesignTokens.hairline, lineWidth: 1)
            }
        }
        .frame(minHeight: DesignTokens.minTapTarget)
        .contentShape(Rectangle())
    }
}

#Preview {
    HStack {
        GarageChipLabel(title: "Brand")
        GarageChipLabel(title: "Hot Wheels", isSelected: true)
    }
    .padding()
    .background(DesignTokens.background)
    .preferredColorScheme(.dark)
}
