import CoreGraphics
import ImageIO
import Testing
import UIKit
@testable import Blister

/// The orientation plumbing every pixel-consuming stage of the photo pipeline depends on. A camera
/// capture is a *landscape* buffer tagged `.right`; getting this wrong is what rotated cleaned
/// photos 90°.
struct ImageOrientationTests {

    // MARK: uprighted

    @Test func rightTaggedImageComesBackUprightWithSwappedDimensionsAndScalePreserved() throws {
        // 40×20 landscape pixels tagged `.right` == the shape a portrait iPhone capture arrives in.
        let buffer = try makeBuffer(width: 40, height: 20)
        let tagged = UIImage(cgImage: buffer, scale: 2, orientation: .right)
        #expect(tagged.size == CGSize(width: 10, height: 20)) // points: already swapped by the tag

        let upright = ImageOrientation.uprighted(tagged)

        #expect(upright.imageOrientation == .up)
        #expect(upright.scale == 2)
        #expect(upright.size == tagged.size)
        // The *pixels* are now portrait too, at the same resolution — nothing downsampled.
        let uprightBuffer = try #require(upright.cgImage)
        #expect(uprightBuffer.width == 20)
        #expect(uprightBuffer.height == 40)
    }

    @Test func uprightingRotatesTheContentInTheRightDirection() throws {
        // White marker in the buffer's top-left. `.right` (EXIF 6) means the buffer must turn 90°
        // clockwise to display, so that marker belongs in the upright image's top-RIGHT.
        let buffer = try makeBuffer(width: 40, height: 20, markerCorner: .topLeft)
        let tagged = UIImage(cgImage: buffer, scale: 1, orientation: .right)
        let upright = ImageOrientation.uprighted(tagged)
        let pixels = try #require(upright.cgImage)

        let topRight = try sample(pixels, x: pixels.width - 3, y: 3)
        let topLeft = try sample(pixels, x: 3, y: 3)
        #expect(topRight > 200, "marker should land top-right, got \(topRight)")
        #expect(topLeft < 60, "top-left should be background, got \(topLeft)")
    }

    @Test func alreadyUprightImageIsReturnedUnchanged() throws {
        let buffer = try makeBuffer(width: 30, height: 10)
        let image = UIImage(cgImage: buffer, scale: 3, orientation: .up)
        // Identity, not just equality — an early-out, no re-render.
        #expect(ImageOrientation.uprighted(image) === image)
    }

    @Test func emptyImageIsReturnedUnchanged() {
        let image = UIImage()
        #expect(ImageOrientation.uprighted(image) === image)
    }

    // MARK: cgOrientation

    @Test func cgOrientationMapsAllEightCases() {
        let expected: [(UIImage.Orientation, CGImagePropertyOrientation)] = [
            (.up, .up), (.down, .down), (.left, .left), (.right, .right),
            (.upMirrored, .upMirrored), (.downMirrored, .downMirrored),
            (.leftMirrored, .leftMirrored), (.rightMirrored, .rightMirrored)
        ]
        #expect(expected.count == 8)
        for (uiKit, exif) in expected {
            #expect(ImageOrientation.cgOrientation(uiKit) == exif)
        }
        // Sanity-check the EXIF values themselves: `.right` is the iPhone-portrait case, value 6.
        #expect(ImageOrientation.cgOrientation(.right).rawValue == 6)
        #expect(ImageOrientation.cgOrientation(.left).rawValue == 8)
        #expect(ImageOrientation.cgOrientation(.up).rawValue == 1)
    }

    // MARK: bufferNormalizedRect

    @Test func bufferRectIsIdentityForUp() {
        let rect = CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4)
        #expect(ImageOrientation.bufferNormalizedRect(rect, orientation: .up) == rect)
    }

    @Test func bufferRectUndoesTheRightRotation() {
        // Oriented-frame box hugging the top-left; for `.right` the buffer's *bottom-left* is what
        // displays top-left, so the mapped box must land there.
        let oriented = CGRect(x: 0, y: 0.8, width: 0.2, height: 0.2)
        let buffer = ImageOrientation.bufferNormalizedRect(oriented, orientation: .right)
        #expect(abs(buffer.minX - 0) < 0.0001)
        #expect(abs(buffer.maxX - 0.2) < 0.0001)
        #expect(abs(buffer.minY - 0) < 0.0001)
        #expect(abs(buffer.maxY - 0.2) < 0.0001)
    }

    @Test func bufferRectRoundTripsThroughEveryOrientation() {
        // Mapping a normalized box back to buffer space then forward again (via the inverse
        // orientation) must return the original, for all eight cases.
        let rect = CGRect(x: 0.15, y: 0.05, width: 0.35, height: 0.6)
        let inverses: [(UIImage.Orientation, UIImage.Orientation)] = [
            (.up, .up), (.down, .down), (.upMirrored, .upMirrored), (.downMirrored, .downMirrored),
            (.left, .right), (.right, .left), (.leftMirrored, .leftMirrored),
            (.rightMirrored, .rightMirrored)
        ]
        for (orientation, inverse) in inverses {
            let there = ImageOrientation.bufferNormalizedRect(rect, orientation: orientation)
            let back = ImageOrientation.bufferNormalizedRect(there, orientation: inverse)
            #expect(abs(back.minX - rect.minX) < 0.0001, "round trip failed for \(orientation)")
            #expect(abs(back.minY - rect.minY) < 0.0001, "round trip failed for \(orientation)")
            #expect(abs(back.width - rect.width) < 0.0001, "round trip failed for \(orientation)")
            #expect(abs(back.height - rect.height) < 0.0001, "round trip failed for \(orientation)")
        }
    }

    // MARK: - Helpers

    private enum MarkerCorner { case none, topLeft }

    /// A `width`×`height` pixel buffer: dark, with an optional white square in one corner.
    private func makeBuffer(width: CGFloat,
                            height: CGFloat,
                            markerCorner: MarkerCorner = .none) throws -> CGImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height),
                                               format: format)
        let image = renderer.image { context in
            UIColor.black.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: width, height: height))
            if markerCorner == .topLeft {
                UIColor.white.setFill()
                context.cgContext.fill(CGRect(x: 0, y: 0, width: width / 3, height: height / 3))
            }
        }
        return try #require(image.cgImage)
    }

    /// Green channel of one pixel, addressed top-left-origin (matching `CGImage.cropping(to:)`).
    private func sample(_ image: CGImage, x: Int, y: Int) throws -> Int {
        let cropped = try #require(image.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)))
        var pixel = [UInt8](repeating: 0, count: 4)
        let drawn: Bool = pixel.withUnsafeMutableBytes { raw in
            guard let context = CGContext(data: raw.baseAddress,
                                          width: 1, height: 1,
                                          bitsPerComponent: 8, bytesPerRow: 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.draw(cropped, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            return true
        }
        #expect(drawn)
        return Int(pixel[1])
    }
}
