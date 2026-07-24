import SwiftUI

/// Placeholder shown for a car that has no photo. Uses the casting name set in large, tightly
/// tracked type — never a generic icon (spec §6.2). The result reads as a serious catalogue entry.
struct TypographicPlaceholder: View {
    let castingName: String
    var brand: Brand? = nil

    private var initials: String {
        let trimmed = castingName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : String(trimmed.prefix(18))
    }

    var body: some View {
        ZStack {
            DesignTokens.background
            Rectangle()
                .stroke(DesignTokens.hairline, lineWidth: 1)
            Text(initials)
                .font(.system(.title3, design: .default, weight: .semibold))
                .tracking(DesignTokens.headingTracking)
                .foregroundStyle(DesignTokens.primaryText)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(DesignTokens.spacingS)
        }
        .accessibilityLabel(Text(castingName.isEmpty ? "Unnamed car" : castingName))
    }
}

#Preview {
    TypographicPlaceholder(castingName: "'67 Camaro")
        .frame(width: 180, height: 180)
}
