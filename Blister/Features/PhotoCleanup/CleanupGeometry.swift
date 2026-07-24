import CoreGraphics
import Foundation

/// Pure rect math for the photo-cleanup composite. **No Vision / CoreImage / UIKit** — only
/// Foundation + CoreGraphics — so every helper is deterministic and unit-testable.
///
/// ## Coordinate conventions
/// Vision reports subject bounds **normalized** (`0...1`) with a **bottom-left** origin, and
/// `VNGenerateForegroundInstanceMaskRequest` yields a masked buffer whose CoreImage extent also
/// uses a **bottom-left** origin. UIKit, by contrast, is top-left. To stay sane, **every rect and
/// size in this type is expressed in a single Cartesian pixel space with a bottom-left origin** —
/// the same space CoreImage composites in. Concretely: for a rect, `minY` is its *lower* edge and
/// larger `y` is *higher* on screen, so "beneath the subject" means *smaller* `y`. The engine
/// converts to/from normalized Vision coordinates and to UIKit only at its edges; the helpers here
/// never do orientation flips.
enum CleanupGeometry {

    /// Expand `subjectBounds` outward by `paddingFraction` of its longer side, then clamp to the
    /// image. Returns the whole image rect for degenerate inputs so callers never crop to nothing.
    /// - Parameters:
    ///   - subjectBounds: subject box in pixels (bottom-left origin), assumed inside the image.
    ///   - imageSize: source image size in pixels.
    ///   - paddingFraction: fraction of the subject's longer side to add on every side (clamped ≥ 0).
    static func paddedCropRect(subjectBounds: CGRect,
                               imageSize: CGSize,
                               paddingFraction: CGFloat) -> CGRect {
        let imageRect = CGRect(origin: .zero, size: imageSize)
        guard subjectBounds.width > 0, subjectBounds.height > 0,
              imageSize.width > 0, imageSize.height > 0 else {
            return imageRect
        }
        let pad = max(0, paddingFraction) * max(subjectBounds.width, subjectBounds.height)
        let expanded = subjectBounds.insetBy(dx: -pad, dy: -pad)
        let clamped = expanded.intersection(imageRect)
        // `intersection` is `.null` when the boxes miss entirely — fall back to the full image.
        return clamped.isNull || clamped.isEmpty ? imageRect : clamped
    }

    /// A square canvas large enough to hold `rect` plus a margin on every side.
    /// - Parameter marginFraction: extra space per side as a fraction of the square's core side.
    static func squareCanvas(around rect: CGRect, marginFraction: CGFloat = 0.12) -> CGSize {
        let base = max(rect.width, rect.height)
        guard base > 0 else { return .zero }
        let side = base * (1 + 2 * max(0, marginFraction))
        return CGSize(width: side, height: side)
    }

    /// Aspect-fit `subject` into `canvas` leaving `marginFraction` of empty space on each side,
    /// centered both ways. The returned rect preserves the subject's aspect ratio, so a single
    /// uniform scale maps the subject onto it.
    static func placement(of subject: CGSize,
                          in canvas: CGSize,
                          marginFraction: CGFloat = 0.12) -> CGRect {
        guard subject.width > 0, subject.height > 0,
              canvas.width > 0, canvas.height > 0 else {
            return .zero
        }
        let m = max(0, min(0.49, marginFraction))
        let availW = canvas.width * (1 - 2 * m)
        let availH = canvas.height * (1 - 2 * m)
        let scale = min(availW / subject.width, availH / subject.height)
        let size = CGSize(width: subject.width * scale, height: subject.height * scale)
        let origin = CGPoint(x: (canvas.width - size.width) / 2,
                             y: (canvas.height - size.height) / 2)
        return CGRect(origin: origin, size: size)
    }

    /// A short mirror-reflection rect sitting flush beneath the subject, for the composite's **UIKit
    /// top-left render space** (distinct from the bottom-left helpers in this type). The reflection
    /// hangs directly below the subject's base (`subjectPlacement.maxY`), the same width and `x`, with
    /// height a fraction of the subject's own. Kept short — a tall carded product's reflection should
    /// stay subtle — and clamped so its bottom edge never passes `canvas.height`.
    static func reflectionRect(under subjectPlacement: CGRect,
                               canvas: CGSize,
                               heightFraction: CGFloat) -> CGRect {
        guard subjectPlacement.width > 0, subjectPlacement.height > 0 else { return .zero }
        let desired = subjectPlacement.height * max(0, heightFraction)
        let available = max(0, canvas.height - subjectPlacement.maxY)
        let height = min(desired, available)
        guard height > 0 else { return .zero }
        return CGRect(x: subjectPlacement.minX, y: subjectPlacement.maxY,
                      width: subjectPlacement.width, height: height)
    }

    /// A flattened ellipse rect for the soft contact shadow, sitting just under the subject's base.
    /// In this bottom-left space the subject's base is `subjectPlacement.minY`; the ellipse is
    /// horizontally centered on the subject and nudged up slightly so it kisses the wheels.
    static func contactShadowRect(under subjectPlacement: CGRect, canvas: CGSize) -> CGRect {
        guard subjectPlacement.width > 0, subjectPlacement.height > 0 else { return .zero }
        let width = subjectPlacement.width * 0.9
        let height = max(1, subjectPlacement.height * 0.14)
        let centerX = subjectPlacement.midX
        // Overlap the base by ~15% of the ellipse height for a grounded look.
        let centerY = subjectPlacement.minY + height * 0.15
        return CGRect(x: centerX - width / 2,
                      y: centerY - height / 2,
                      width: width,
                      height: height)
    }
}
