import CoreGraphics
import UIKit

/// Builds deterministic stand-in photos for the photo-cleanup tests: a bright blister card on a dark
/// ground, optionally tilted, optionally gripped by skin-toned "hand" blobs above and below it —
/// the exact situation ``CardDetector`` exists to solve.
///
/// Deterministic so tests can assert on the card's corners to the pixel. Test-target only.
enum SyntheticCardScene {

    /// Fill used for the "fingers" and "palm". Distinct enough from the card and the ground that a
    /// test can count how much of it survived a crop.
    static let skinTone = UIColor(red: 0.90, green: 0.72, blue: 0.58, alpha: 1)

    /// Gap between the hand blobs and the card edge, so a small crop margin can't clip skin back in.
    static let handClearance: CGFloat = 30

    /// - Parameters:
    ///   - imageSize: canvas size in pixels (scale 1, so points == pixels).
    ///   - cardSize: the card's own width × height before tilting.
    ///   - degrees: clockwise tilt of the card about the canvas centre.
    ///   - withHands: draw fingers above and a ringed palm below the card.
    /// - Returns: the rendered image plus the card's corners in **top-left** pixel space, ordered
    ///   `[topLeft, topRight, bottomRight, bottomLeft]`.
    static func card(imageSize: CGSize = CGSize(width: 900, height: 1200),
                     cardSize: CGSize = CGSize(width: 420, height: 620),
                     degrees: CGFloat = 8,
                     withHands: Bool = false) -> (image: UIImage, corners: [CGPoint]) {
        let center = CGPoint(x: imageSize.width / 2, y: imageSize.height / 2)
        let corners = tiltedCorners(center: center, size: cardSize, degrees: degrees)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: imageSize, format: format)

        let image = renderer.image { context in
            let cg = context.cgContext

            // Dark, slightly uneven ground — a totally flat fill can read as "no image content".
            UIColor(white: 0.10, alpha: 1).setFill()
            cg.fill(CGRect(origin: .zero, size: imageSize))
            UIColor(white: 0.16, alpha: 1).setFill()
            cg.fill(CGRect(x: 0, y: imageSize.height * 0.72,
                           width: imageSize.width, height: imageSize.height * 0.28))

            if withHands {
                skinTone.setFill()
                // Three fingers curling over the top edge of the card.
                let fingerTop = corners[0].y - handClearance - 150
                for index in 0..<3 {
                    let x = center.x - 150 + CGFloat(index) * 110
                    cg.fillEllipse(in: CGRect(x: x, y: fingerTop, width: 76, height: 150))
                }
                // A palm below it, plus a bright band standing in for a ring.
                let palmTop = corners[2].y + handClearance
                cg.fillEllipse(in: CGRect(x: center.x - 200, y: palmTop, width: 400, height: 210))
                UIColor(white: 0.85, alpha: 1).setFill()
                cg.fill(CGRect(x: center.x - 40, y: palmTop + 60, width: 80, height: 26))
            }

            // The card: a bright panel with a darker printed window, so it has a real edge and some
            // interior structure rather than being one flat blob.
            let path = UIBezierPath()
            path.move(to: corners[0])
            for corner in corners.dropFirst() { path.addLine(to: corner) }
            path.close()
            UIColor(white: 0.93, alpha: 1).setFill()
            path.fill()

            cg.saveGState()
            path.addClip()
            UIColor(red: 0.15, green: 0.35, blue: 0.62, alpha: 1).setFill()
            cg.fill(CGRect(x: center.x - cardSize.width * 0.32,
                           y: center.y - cardSize.height * 0.12,
                           width: cardSize.width * 0.64,
                           height: cardSize.height * 0.42))
            cg.restoreGState()
        }
        return (image, corners)
    }

    /// The four corners of a `size` rectangle centred on `center` and rotated `degrees` clockwise in
    /// UIKit's top-left space, ordered `[topLeft, topRight, bottomRight, bottomLeft]`.
    static func tiltedCorners(center: CGPoint, size: CGSize, degrees: CGFloat) -> [CGPoint] {
        let radians = degrees * .pi / 180
        let halfWidth = size.width / 2
        let halfHeight = size.height / 2
        func point(_ dx: CGFloat, _ dy: CGFloat) -> CGPoint {
            CGPoint(x: center.x + dx * cos(radians) - dy * sin(radians),
                    y: center.y + dx * sin(radians) + dy * cos(radians))
        }
        return [point(-halfWidth, -halfHeight), point(halfWidth, -halfHeight),
                point(halfWidth, halfHeight), point(-halfWidth, halfHeight)]
    }

    /// The same picture stored the way a phone actually hands one over: a **landscape** buffer
    /// tagged `.right`, which displays portrait. Anything that reaches for `.cgImage` without first
    /// honouring `imageOrientation` sees this sideways.
    static func asRightTaggedCapture(_ image: UIImage) -> UIImage? {
        guard let source = image.cgImage else { return nil }
        let canvas = CGSize(width: CGFloat(source.height), height: CGFloat(source.width))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: canvas, format: format)
        let sideways = renderer.image { context in
            let cg = context.cgContext
            // Rotate the picture 90° counter-clockwise into the landscape canvas, so tagging the
            // result `.right` (rotate 90° clockwise to display) restores the original.
            cg.translateBy(x: 0, y: canvas.height)
            cg.rotate(by: -.pi / 2)
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        guard let buffer = sideways.cgImage else { return nil }
        return UIImage(cgImage: buffer, scale: 1, orientation: .right)
    }

    /// Mean absolute per-channel difference (`0...1`) between two images, compared at a coarse
    /// `grid`×`grid` resolution so incidental resampling noise doesn't register but a 90° rotation
    /// very much does.
    static func meanChannelDifference(_ lhs: CGImage, _ rhs: CGImage, grid: Int = 16) -> Double {
        guard let a = downsampled(lhs, grid: grid), let b = downsampled(rhs, grid: grid) else {
            return 1
        }
        let total = zip(a, b).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }
        return Double(total) / Double(a.count) / 255
    }

    private static func downsampled(_ image: CGImage, grid: Int) -> [UInt8]? {
        var pixels = [UInt8](repeating: 0, count: grid * grid * 4)
        let drawn: Bool = pixels.withUnsafeMutableBytes { raw in
            guard let context = CGContext(data: raw.baseAddress,
                                          width: grid, height: grid,
                                          bitsPerComponent: 8, bytesPerRow: grid * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: grid, height: grid))
            return true
        }
        return drawn ? pixels : nil
    }

    /// A featureless mid-grey image — nothing for the rectangle detector to lock onto.
    static func blank(size: CGSize = CGSize(width: 900, height: 1200)) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            UIColor(white: 0.5, alpha: 1).setFill()
            context.cgContext.fill(CGRect(origin: .zero, size: size))
        }
    }

    /// Fraction of `image`'s pixels that are close to ``skinTone``. Used to prove a crop actually
    /// removed the hand rather than merely shrinking the frame.
    static func skinFraction(of image: CGImage) -> Double {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return 0 }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        let drawn: Bool = pixels.withUnsafeMutableBytes { raw in
            guard let context = CGContext(data: raw.baseAddress,
                                          width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: width * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: bitmapInfo) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return 0 }

        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard skinTone.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return 0 }
        let target = (r: red * 255, g: green * 255, b: blue * 255)

        var matches = 0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let dr = abs(CGFloat(pixels[index]) - target.r)
            let dg = abs(CGFloat(pixels[index + 1]) - target.g)
            let db = abs(CGFloat(pixels[index + 2]) - target.b)
            if dr < 26, dg < 26, db < 26 { matches += 1 }
        }
        return Double(matches) / Double(width * height)
    }
}
