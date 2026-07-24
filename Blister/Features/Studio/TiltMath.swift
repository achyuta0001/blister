import CoreGraphics
import Foundation

/// Pure, SwiftUI-free math for the "tilt + sheen" hero interaction.
///
/// Dependency-light (Foundation / CoreGraphics only) so it unit-tests without a view hierarchy.
///
/// ## Convention
/// A drag *translation* (points, from the gesture start) maps to two rotation angles, in degrees:
/// - **Dragging right** (`translation.width > 0`) → **positive `y`** angle. Applied as a
///   `rotation3DEffect` about the Y axis, the card's right edge swings back — it "faces" the drag.
/// - **Dragging up** (`translation.height < 0`) → **positive `x`** angle. Applied about the X axis,
///   the card's top edge swings back.
///
/// Both angles are proportional to how far the drag has travelled relative to half the view's
/// corresponding dimension, and are clamped to `±maxDegrees`.
enum TiltMath {

    /// Maps a drag translation to clamped tilt angles (degrees) using the documented convention.
    ///
    /// - Parameters:
    ///   - translation: Drag translation in points, relative to the gesture start.
    ///   - size: The size of the tilted view. Non-positive dimensions yield a zero angle on that axis.
    ///   - maxDegrees: The clamp bound; the returned angles lie in `[-maxDegrees, maxDegrees]`.
    /// - Returns: `(x, y)` rotation angles in degrees.
    static func tiltAngles(
        for translation: CGSize,
        in size: CGSize,
        maxDegrees: Double = 12
    ) -> (x: Double, y: Double) {
        let halfWidth = size.width / 2
        let halfHeight = size.height / 2

        let rawY = halfWidth > 0 ? Double(translation.width) / Double(halfWidth) * maxDegrees : 0
        // Up drag is a negative height, and should read as a positive X angle.
        let rawX = halfHeight > 0 ? Double(-translation.height) / Double(halfHeight) * maxDegrees : 0

        return (x: clamp(rawX, to: maxDegrees), y: clamp(rawY, to: maxDegrees))
    }

    /// The offset of the diagonal sheen highlight, tracking the tilt.
    ///
    /// The highlight slides *with* the tilt: a positive `y` angle (right drag) pushes it right, and a
    /// positive `x` angle (up drag) pushes it up (negative offset height, matching screen coordinates
    /// where up is negative). At zero tilt the sheen is centred (`.zero`).
    ///
    /// - Parameters:
    ///   - angles: The tilt angles from ``tiltAngles(for:in:maxDegrees:)``.
    ///   - maxDegrees: The same clamp bound used to produce `angles`; normalises the offset.
    ///   - travel: The maximum distance in points the highlight moves from centre on each axis.
    /// - Returns: A `CGSize` offset for the highlight overlay.
    static func sheenOffset(
        for angles: (x: Double, y: Double),
        maxDegrees: Double = 12,
        travel: CGFloat = 60
    ) -> CGSize {
        guard maxDegrees > 0 else { return .zero }
        let nx = clamp(angles.y, to: maxDegrees) / maxDegrees
        let ny = clamp(angles.x, to: maxDegrees) / maxDegrees
        return CGSize(
            width: CGFloat(nx) * travel,
            height: CGFloat(-ny) * travel
        )
    }

    /// Clamps `value` to `[-bound, bound]`.
    private static func clamp(_ value: Double, to bound: Double) -> Double {
        min(max(value, -bound), bound)
    }
}
