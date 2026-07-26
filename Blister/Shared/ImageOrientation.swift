import CoreGraphics
import ImageIO
import UIKit

/// Orientation plumbing shared by every stage of the photo pipeline that touches raw pixels.
///
/// A `UIImage` from the camera or the photo picker keeps its capture rotation as *metadata*
/// (`imageOrientation`) rather than in the buffer: an iPhone portrait shot is a **landscape**
/// `CGImage` tagged `.right`. Anything that reaches for `.cgImage` (Vision, Core Image, HEIC
/// encoding, `CGImage.cropping`) therefore sees sideways pixels unless the caller either bakes the
/// rotation in first or hands the orientation to the framework.
///
/// This type is the single home for both moves, so no pipeline stage grows its own private copy:
/// - ``uprighted(_:)`` — re-render so the pixels themselves stand up (use before a stage that has
///   no orientation input, or when the result is written to disk).
/// - ``cgOrientation(_:)`` — the EXIF equivalent to hand to a Vision request handler, when
///   re-rendering the whole buffer would be wasted work.
/// - ``bufferNormalizedRect(_:orientation:)`` — maps a Vision result back into raw-buffer space
///   after using ``cgOrientation(_:)``, because Vision reports normalized boxes in the *oriented*
///   frame, not the buffer's.
///
/// Pure and side-effect free. Never throws, never force-unwraps.
enum ImageOrientation {

    /// The same image with its capture rotation baked into the pixels, so `cgImage` is upright.
    ///
    /// Returns the input untouched when it is already `.up` (the common case — no allocation), and
    /// preserves `scale` so a Retina image is not silently downsampled.
    static func uprighted(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }

    /// The EXIF orientation matching a `UIImage.Orientation`, for `VNImageRequestHandler` and
    /// friends. The mapping is name-for-name: both enums describe the *same* eight EXIF cases
    /// (`UIImage.Orientation.right` and `CGImagePropertyOrientation.right` are both EXIF value 6,
    /// the iPhone-held-portrait case).
    static func cgOrientation(_ orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: .up
        case .upMirrored: .upMirrored
        case .down: .down
        case .downMirrored: .downMirrored
        case .left: .left
        case .leftMirrored: .leftMirrored
        case .right: .right
        case .rightMirrored: .rightMirrored
        @unknown default: .up
        }
    }

    /// Maps a normalized rect Vision reported in the **oriented** frame back into the **raw
    /// buffer's** normalized frame, so a caller that handed `orientation` to the request handler can
    /// still crop the untouched `CGImage`.
    ///
    /// Both spaces are normalized `0...1` with a bottom-left origin (Vision's convention). Corners
    /// are mapped individually and re-bounded, which is exact for the 90° rotations and mirrors that
    /// EXIF orientations describe.
    static func bufferNormalizedRect(_ rect: CGRect,
                                     orientation: UIImage.Orientation) -> CGRect {
        guard orientation != .up else { return rect }
        let corners = [
            CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY)
        ].map { bufferNormalizedPoint($0, orientation: orientation) }

        let xs = corners.map(\.x)
        let ys = corners.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max() else { return rect }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Oriented-frame normalized point → buffer-frame normalized point (both bottom-left origin).
    ///
    /// Derived from the EXIF definitions of each case: e.g. `.right` (EXIF 6) means the buffer must
    /// be rotated 90° clockwise to display, so the buffer's left edge becomes the oriented image's
    /// top edge — hence `x_buffer = 1 - y_oriented`, `y_buffer = x_oriented`.
    private static func bufferNormalizedPoint(_ point: CGPoint,
                                              orientation: UIImage.Orientation) -> CGPoint {
        switch orientation {
        case .up: point
        case .upMirrored: CGPoint(x: 1 - point.x, y: point.y)
        case .down: CGPoint(x: 1 - point.x, y: 1 - point.y)
        case .downMirrored: CGPoint(x: point.x, y: 1 - point.y)
        case .left: CGPoint(x: point.y, y: 1 - point.x)
        case .leftMirrored: CGPoint(x: 1 - point.y, y: 1 - point.x)
        case .right: CGPoint(x: 1 - point.y, y: point.x)
        case .rightMirrored: CGPoint(x: point.y, y: point.x)
        @unknown default: point
        }
    }
}
