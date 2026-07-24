import SwiftUI

/// Central visual constants (spec §7). Deliberately not toy-like: near-black background, near-white
/// text, a single accent colour, no gradients or drop shadows. Car photographs are the only colour
/// in the interface. Frozen contract — every feature reads from here so the app looks like one app.
enum DesignTokens {
    /// `#1C1C1C` app background.
    static let background = Color(red: 0x1C / 255, green: 0x1C / 255, blue: 0x1C / 255)

    /// Near-white primary text.
    static let primaryText = Color(white: 0.96)

    /// Muted secondary text.
    static let secondaryText = Color(white: 0.62)

    /// Faint separators / chip outlines.
    static let hairline = Color(white: 0.24)

    /// The single accent colour — hunt status and destructive actions only (from asset catalog).
    static let accent = Color("AccentColor")

    // Spacing scale.
    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 16
    static let spacingL: CGFloat = 24

    /// Minimum tap target (spec §7 accessibility).
    static let minTapTarget: CGFloat = 44

    /// Tight tracking for headings.
    static let headingTracking: CGFloat = -0.5
}
