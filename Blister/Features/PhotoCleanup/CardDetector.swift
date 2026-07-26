import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit
import Vision
import os

/// Finds the blister card in a photo and returns a deskewed image of **just the card**.
///
/// Most photos in this app are of *carded* castings held in one hand: fingers curl over the top of
/// the card and a hand (often with a ring) sits below it. Subject-lifting can't separate those —
/// hand and card are usually one connected foreground instance — so the primary cleanup path
/// instead looks for the card's own quadrilateral with `VNDetectRectanglesRequest` and applies
/// `CIPerspectiveCorrection` to it. That single step both squares the card up and clips to its
/// edges, so everything outside the card (fingers, hand, background) simply isn't in the output.
///
/// Runs entirely on device, Apple frameworks only. Returns `nil` whenever no card-like rectangle is
/// found so the caller can fall back to the subject lift; it never throws.
///
/// ## Coordinate conventions
/// Corners are in **pixel** coordinates with a **bottom-left** origin — the space Core Image
/// composites in and the space `VNImagePointForNormalizedPoint` produces — so no flips happen
/// between detection and correction. The input `CGImage` is assumed already upright (see
/// ``ImageOrientation/uprighted(_:)``); a sideways buffer would be measured sideways.
enum CardDetector {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Blister",
                                       category: "CardDetector")

    /// Shared context — `CIContext` is expensive to build and is safe to reuse across threads.
    private static let context = CIContext()

    /// The four corners of a detected card, bottom-left-origin pixel space.
    struct Quad: Equatable, Sendable {
        var topLeft: CGPoint
        var topRight: CGPoint
        var bottomLeft: CGPoint
        var bottomRight: CGPoint

        var corners: [CGPoint] { [topLeft, topRight, bottomRight, bottomLeft] }

        /// Axis-aligned box containing all four corners.
        var boundingBox: CGRect {
            let xs = corners.map(\.x)
            let ys = corners.map(\.y)
            guard let minX = xs.min(), let maxX = xs.max(),
                  let minY = ys.min(), let maxY = ys.max() else { return .zero }
            return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        }

        var centroid: CGPoint {
            CGPoint(x: corners.reduce(0) { $0 + $1.x } / 4, y: corners.reduce(0) { $0 + $1.y } / 4)
        }

        /// Enclosed area via the shoelace formula — a truer size measure than ``boundingBox`` for a
        /// tilted card, so ranking doesn't favour whichever rectangle happens to be most skewed.
        var area: CGFloat {
            let points = corners
            var sum: CGFloat = 0
            for index in points.indices {
                let a = points[index]
                let b = points[(index + 1) % points.count]
                sum += a.x * b.y - b.x * a.y
            }
            return abs(sum) / 2
        }

        /// The quad scaled uniformly about its own centroid, then clamped inside `bounds` so no
        /// corner samples outside the source image.
        func expanded(by scale: CGFloat, within bounds: CGRect) -> Quad {
            let center = centroid
            func move(_ point: CGPoint) -> CGPoint {
                let scaled = CGPoint(x: center.x + (point.x - center.x) * scale,
                                     y: center.y + (point.y - center.y) * scale)
                return CGPoint(x: min(max(scaled.x, bounds.minX), bounds.maxX),
                               y: min(max(scaled.y, bounds.minY), bounds.maxY))
            }
            return Quad(topLeft: move(topLeft), topRight: move(topRight),
                        bottomLeft: move(bottomLeft), bottomRight: move(bottomRight))
        }
    }

    // MARK: - Tuning

    /// Rectangle-detector tuning for a hand-held blister card.
    ///
    /// Vision's aspect-ratio bounds are *short side ÷ long side* (range `0...1`), so they are
    /// orientation-agnostic: a 1:64 blister card measures roughly 0.6–0.8 either way up. The window
    /// is widened a little at both ends to survive perspective foreshortening, while still rejecting
    /// the near-square and very elongated rectangles that tables, tiles, shelf edges and door frames
    /// produce.
    private static let minimumAspectRatio: Float = 0.45
    private static let maximumAspectRatio: Float = 0.95
    /// As a proportion of the image's *smallest* dimension — a card someone is photographing fills a
    /// good part of the frame, and this rejects small background rectangles outright.
    private static let minimumSize: Float = 0.25
    /// Degrees a corner may deviate from 90°. Below Vision's default 30 because a card held at arm's
    /// length is only mildly keystoned, and a tighter tolerance keeps out incidental quadrilaterals.
    private static let quadratureTolerance: Float = 25
    private static let minimumConfidence: Float = 0.6
    /// Several plausible rectangles are usually present (card, bubble, printed panel); collect a few
    /// and rank them rather than trusting Vision's first.
    private static let maximumObservations = 8
    /// Slack added around the detected quad so the card's printed border isn't shaved off. Kept
    /// deliberately tiny — the whole point of this path is to cut *at* the card edge, and every
    /// extra pixel is background (or finger) coming back in.
    ///
    /// Measured against the synthetic fixtures at 0°/7°/15°/25° tilt, Vision's raw corners land
    /// within ~3 px of the true card and enclose ~100.5% of its area, i.e. it already errs very
    /// slightly *outward* on a hard edge. Real cards have a soft shadow and an overhanging plastic
    /// bubble, so a small positive margin is still worth carrying; 0.02 is ~8 px on a 420 px card.
    static let defaultPaddingFraction: CGFloat = 0.02

    // MARK: - API

    /// The best card-like rectangle in `image`, or `nil` when there isn't one.
    static func detect(in image: CGImage) -> Quad? {
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = minimumAspectRatio
        request.maximumAspectRatio = maximumAspectRatio
        request.minimumSize = minimumSize
        request.quadratureTolerance = quadratureTolerance
        request.minimumConfidence = minimumConfidence
        request.maximumObservations = maximumObservations

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            logger.error("Rectangle request failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }

        guard let observations = request.results, !observations.isEmpty else {
            logger.debug("No card-like rectangle found")
            return nil
        }

        let width = image.width
        let height = image.height
        let quads = observations.map { observation in
            (quad: Quad(
                topLeft: VNImagePointForNormalizedPoint(observation.topLeft, width, height),
                topRight: VNImagePointForNormalizedPoint(observation.topRight, width, height),
                bottomLeft: VNImagePointForNormalizedPoint(observation.bottomLeft, width, height),
                bottomRight: VNImagePointForNormalizedPoint(observation.bottomRight, width, height)
             ),
             confidence: CGFloat(observation.confidence))
        }

        // Rank by confidence × enclosed area: the card is the big, cleanly-edged rectangle, while
        // panels printed *on* it score similar confidence over a much smaller area.
        let best = quads.max { lhs, rhs in
            lhs.confidence * lhs.quad.area < rhs.confidence * rhs.quad.area
        }
        return best?.quad
    }

    /// A deskewed, tightly-cropped image of the card in `image`, or `nil` when no card is found.
    ///
    /// The padding uses ``CleanupGeometry/paddedCropRect(subjectBounds:imageSize:paddingFraction:)``
    /// so the expansion (and its clamp to the image) shares the pipeline's existing rect math; the
    /// resulting growth factor is then applied uniformly about the quad's centroid so a tilted card
    /// stays a rectangle rather than turning into its bounding box.
    static func croppedCard(from image: CGImage,
                            paddingFraction: CGFloat = defaultPaddingFraction) -> CGImage? {
        guard let quad = detect(in: image) else { return nil }
        let imageSize = CGSize(width: image.width, height: image.height)
        return perspectiveCorrected(image, quad: padded(quad,
                                                        imageSize: imageSize,
                                                        paddingFraction: paddingFraction))
    }

    /// `quad` grown by a small margin and kept inside the image.
    static func padded(_ quad: Quad, imageSize: CGSize, paddingFraction: CGFloat) -> Quad {
        let bounds = quad.boundingBox
        let imageRect = CGRect(origin: .zero, size: imageSize)
        guard bounds.width > 0, bounds.height > 0,
              imageSize.width > 0, imageSize.height > 0 else { return quad }

        let target = CleanupGeometry.paddedCropRect(subjectBounds: bounds,
                                                    imageSize: imageSize,
                                                    paddingFraction: paddingFraction)
        // Whichever axis the image clamped hardest sets the growth, so the expansion never runs off
        // the frame; never shrink (`max(1, …)`) — this margin is additive only.
        let scale = max(1, min(target.width / bounds.width, target.height / bounds.height))
        return quad.expanded(by: scale, within: imageRect)
    }

    /// Warps the quad back to a straight-on rectangle, discarding everything outside it.
    private static func perspectiveCorrected(_ image: CGImage, quad: Quad) -> CGImage? {
        let filter = CIFilter.perspectiveCorrection()
        filter.inputImage = CIImage(cgImage: image)
        filter.topLeft = quad.topLeft
        filter.topRight = quad.topRight
        filter.bottomLeft = quad.bottomLeft
        filter.bottomRight = quad.bottomRight
        filter.crop = true

        guard let output = filter.outputImage,
              !output.extent.isEmpty, !output.extent.isInfinite,
              output.extent.width >= 1, output.extent.height >= 1 else {
            logger.error("Perspective correction produced no usable image")
            return nil
        }
        guard let corrected = context.createCGImage(output, from: output.extent) else {
            logger.error("Could not rasterise the corrected card")
            return nil
        }
        return corrected
    }
}
