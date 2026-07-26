import CoreGraphics
import UIKit
import Vision
import os

/// Salience-aware crop for grid thumbnails, so cards are consistently framed on the casting.
///
/// Uses Vision's attention-based saliency to find the region a viewer looks at (for a *carded*
/// product that's the whole flat, usually portrait card), expands it to the target aspect **without
/// ever cropping into the salient region**, and clamps to the image. If saliency yields nothing it
/// falls back to a plain centre crop. Never crashes; returns `nil` only when there's no drawable
/// image.
///
/// The pure rect math lives in ``cropRect(salientRect:imageSize:targetAspect:)`` and
/// ``centerCropRect(imageSize:targetAspect:)`` so it is deterministic and unit-testable.
enum SaliencyCropper {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Blister",
                                       category: "SaliencyCropper")

    static func centeredCrop(_ image: UIImage, targetAspect: CGFloat = 1) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        guard imageSize.width > 0, imageSize.height > 0 else { return nil }

        // Everything below works in **raw buffer space** (`cgImage.cropping` and the re-tag on the
        // way out both do), but Vision must still analyse the image the right way up — a sideways
        // card is not what a viewer's attention lands on. So the orientation is handed to the
        // request handler and its results are mapped back into buffer space, rather than paying for
        // a full re-render of a photo we are only going to shrink to a 400px thumbnail.
        let crop = salientCropRect(for: cgImage,
                                   imageSize: imageSize,
                                   orientation: image.imageOrientation,
                                   targetAspect: targetAspect)
        let integral = crop.integral.intersection(CGRect(origin: .zero, size: imageSize))
        guard !integral.isNull, integral.width >= 1, integral.height >= 1,
              let cropped = cgImage.cropping(to: integral) else {
            return image
        }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }

    /// Runs Vision saliency (falling back to a centre crop) and returns the crop rect in top-left
    /// pixel space **of the raw buffer**, having analysed the image in its upright orientation.
    private static func salientCropRect(for cgImage: CGImage,
                                        imageSize: CGSize,
                                        orientation: UIImage.Orientation,
                                        targetAspect: CGFloat) -> CGRect {
        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            logger.error("Saliency request failed: \(error.localizedDescription, privacy: .public)")
            return centerCropRect(imageSize: imageSize, targetAspect: targetAspect)
        }

        guard let observation = request.results?.first,
              let objects = observation.salientObjects, !objects.isEmpty else {
            // Vision found nothing salient (common on blank/low-contrast shots) — centre crop.
            return centerCropRect(imageSize: imageSize, targetAspect: targetAspect)
        }

        // Union every salient object so the whole card stays in frame. Vision boxes are normalized
        // with a bottom-left origin; convert to top-left pixel space.
        var union = objects[0].boundingBox
        for object in objects.dropFirst() { union = union.union(object.boundingBox) }
        let pixel = VNImageRectForNormalizedRect(union, cgImage.width, cgImage.height)
        let topLeft = CGRect(x: pixel.minX,
                             y: imageSize.height - pixel.maxY,
                             width: pixel.width,
                             height: pixel.height)
        return cropRect(salientRect: topLeft, imageSize: imageSize, targetAspect: targetAspect)
    }

    /// The smallest rect of `targetAspect` that **fully contains** `salientRect`, centred on the
    /// salient centre and clamped inside the image. It only ever adds padding around the salient
    /// region — it never crops into it — so a tall carded product keeps its header, name and car in
    /// frame. When the target aspect can't be reached without exceeding the image (e.g. a very tall
    /// card in a square target), the rect falls back to the image dimension in that axis, preserving
    /// the whole card at a slightly off-target aspect rather than cutting it.
    static func cropRect(salientRect: CGRect, imageSize: CGSize, targetAspect: CGFloat) -> CGRect {
        let imageRect = CGRect(origin: .zero, size: imageSize)
        guard imageSize.width > 0, imageSize.height > 0, targetAspect > 0 else { return imageRect }
        let salient = salientRect.intersection(imageRect)
        guard !salient.isNull, salient.width > 0, salient.height > 0 else { return imageRect }

        var width = salient.width
        var height = salient.height
        if width / height < targetAspect {
            width = height * targetAspect   // too tall for the target — widen.
        } else {
            height = width / targetAspect   // too wide for the target — heighten.
        }

        // Never exceed the image; never shrink below the salient region (preserve the whole card).
        width = min(max(width, salient.width), imageSize.width)
        height = min(max(height, salient.height), imageSize.height)

        var x = salient.midX - width / 2
        var y = salient.midY - height / 2
        x = min(max(x, 0), imageSize.width - width)
        y = min(max(y, 0), imageSize.height - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// A centred crop of `targetAspect` filling the image in one axis. Used when Vision finds nothing.
    static func centerCropRect(imageSize: CGSize, targetAspect: CGFloat) -> CGRect {
        let imageRect = CGRect(origin: .zero, size: imageSize)
        guard imageSize.width > 0, imageSize.height > 0, targetAspect > 0 else { return imageRect }
        var width = imageSize.width
        var height = imageSize.height
        if width / height > targetAspect {
            width = height * targetAspect
        } else {
            height = width / targetAspect
        }
        return CGRect(x: (imageSize.width - width) / 2,
                      y: (imageSize.height - height) / 2,
                      width: width,
                      height: height)
    }
}
