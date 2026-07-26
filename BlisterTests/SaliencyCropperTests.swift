import Testing
import CoreGraphics
import UIKit
@testable import Blister

/// Pure crop-rect math for the saliency thumbnail cropper. All rects are top-left pixel space.
struct SaliencyCropperTests {

    // MARK: centerCropRect (fallback)

    @Test func centerCropIsCenteredAndHitsTargetAspect() {
        let image = CGSize(width: 1000, height: 600)
        let crop = SaliencyCropper.centerCropRect(imageSize: image, targetAspect: 1)
        // Square crop of a landscape image: side == the shorter edge, centred.
        #expect(crop.width == 600)
        #expect(crop.height == 600)
        #expect(abs(crop.midX - image.width / 2) < 0.0001)
        #expect(abs(crop.midY - image.height / 2) < 0.0001)
        #expect(crop.minX >= 0)
        #expect(crop.maxX <= image.width + 0.0001)
    }

    @Test func centerCropWithDegenerateImageReturnsImageRect() {
        #expect(SaliencyCropper.centerCropRect(imageSize: .zero, targetAspect: 1) == .zero)
    }

    // MARK: cropRect — aspect expansion

    @Test func expandsTallSalientToSquareByWidening() {
        // A tall salient card centred in a wide image; square target should widen, not chop height.
        let image = CGSize(width: 1000, height: 1000)
        let salient = CGRect(x: 450, y: 200, width: 100, height: 600) // portrait card
        let crop = SaliencyCropper.cropRect(salientRect: salient, imageSize: image, targetAspect: 1)
        // Square achieved by widening to the card's height.
        #expect(abs(crop.width - crop.height) < 0.0001)
        #expect(crop.height >= salient.height - 0.0001)
        // The whole card is still inside the crop (nothing cut).
        #expect(crop.minX <= salient.minX + 0.0001)
        #expect(crop.maxX >= salient.maxX - 0.0001)
        #expect(crop.minY <= salient.minY + 0.0001)
        #expect(crop.maxY >= salient.maxY - 0.0001)
    }

    // MARK: cropRect — clamping / preserve-the-card fallback

    @Test func clampsCropInsideImageBounds() {
        // Salient hugs the left edge; the widened square must slide inside the image, not run off it.
        let image = CGSize(width: 1000, height: 1000)
        let salient = CGRect(x: 0, y: 100, width: 80, height: 400)
        let crop = SaliencyCropper.cropRect(salientRect: salient, imageSize: image, targetAspect: 1)
        #expect(crop.minX >= -0.0001)
        #expect(crop.minY >= -0.0001)
        #expect(crop.maxX <= image.width + 0.0001)
        #expect(crop.maxY <= image.height + 0.0001)
        // Card fully preserved.
        #expect(crop.minX <= salient.minX + 0.0001)
        #expect(crop.maxX >= salient.maxX - 0.0001)
    }

    @Test func preservesFullCardWhenSquareCannotFit() {
        // Card is taller than the image is wide: a true square can't contain it — keep the whole card
        // by falling back to the full width rather than cropping its top/bottom.
        let image = CGSize(width: 300, height: 1000)
        let salient = CGRect(x: 50, y: 50, width: 200, height: 800)
        let crop = SaliencyCropper.cropRect(salientRect: salient, imageSize: image, targetAspect: 1)
        #expect(crop.width <= image.width + 0.0001)
        // The whole card is still contained (top and bottom not cut).
        #expect(crop.minY <= salient.minY + 0.0001)
        #expect(crop.maxY >= salient.maxY - 0.0001)
    }

    @Test func cropRectWithDegenerateInputReturnsImageRect() {
        let image = CGSize(width: 640, height: 480)
        #expect(SaliencyCropper.cropRect(salientRect: .zero, imageSize: image, targetAspect: 1)
                == CGRect(origin: .zero, size: image))
    }

    // MARK: bufferCropRect — Vision-normalized box → raw-buffer crop rect
    //
    // These are the real cover for the orientation fix. They call the pure mapping directly, so
    // they assert the exact math that was wrong **without needing the saliency model to run** —
    // `VNGenerateAttentionBasedSaliencyImageRequest` is ML-backed and cannot build an inference
    // context in the simulator ("Failed to create espresso context"), which is also where CI runs.
    // Do not rewrite these to go through `centeredCrop`: that test can only be meaningful on real
    // hardware and would fail in CI.

    @Test func mapsAnOrientedSalientBoxOntoTheRawBufferForAnUprightPhoto() {
        // Portrait 800×1200 buffer, no rotation tag: Vision's frame *is* the buffer's frame.
        let crop = SaliencyCropper.bufferCropRect(
            salientNormalizedRect: CGRect(x: 0.3, y: 0.25, width: 0.4, height: 0.5),
            imageSize: CGSize(width: 800, height: 1200),
            orientation: .up,
            targetAspect: 1
        )
        // Salient box is 320×600 at top-left (240, 300); the square that contains it is 600×600
        // centred on it.
        #expect(crop == CGRect(x: 100, y: 300, width: 600, height: 600))
    }

    @Test func mapsAnOrientedSalientBoxOntoTheRawBufferForARightTaggedCapture() {
        // Same scene, but stored the way a phone hands it over: a landscape 1200×800 buffer tagged
        // `.right`. Vision analysed the *upright* 800×1200 image, so it reports the same normalized
        // box as above — and the crop must still land on the subject in the sideways buffer.
        let crop = SaliencyCropper.bufferCropRect(
            salientNormalizedRect: CGRect(x: 0.3, y: 0.25, width: 0.4, height: 0.5),
            imageSize: CGSize(width: 1200, height: 800),
            orientation: .right,
            targetAspect: 1
        )
        #expect(crop == CGRect(x: 300, y: 100, width: 600, height: 600))
    }

    @Test func theTwoCropsDescribeTheSamePixelsOnceRotationIsUndone() {
        // The point of the two cases above, made explicit. The `.right` buffer is the upright one
        // rotated 90° counter-clockwise, which maps top-left point (x, y) → (y, 800 - x). Applying
        // that to the upright crop must reproduce the tagged crop exactly — if the orientation were
        // dropped, the tagged crop would land somewhere else entirely.
        let upright = SaliencyCropper.bufferCropRect(
            salientNormalizedRect: CGRect(x: 0.3, y: 0.25, width: 0.4, height: 0.5),
            imageSize: CGSize(width: 800, height: 1200), orientation: .up, targetAspect: 1
        )
        let tagged = SaliencyCropper.bufferCropRect(
            salientNormalizedRect: CGRect(x: 0.3, y: 0.25, width: 0.4, height: 0.5),
            imageSize: CGSize(width: 1200, height: 800), orientation: .right, targetAspect: 1
        )
        let rotated = CGRect(x: upright.minY, y: 800 - upright.maxX,
                             width: upright.height, height: upright.width)
        #expect(rotated == tagged)
    }

    @Test func dropsTheOrientationOnlyWhenThereIsNoneToDrop() {
        // A `.up` mapping must be a plain scale-and-flip, i.e. unchanged by the buffer remap.
        let box = CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2)
        let size = CGSize(width: 500, height: 500)
        // Square image + square target: the crop is just the salient box in top-left pixels.
        #expect(SaliencyCropper.bufferCropRect(salientNormalizedRect: box, imageSize: size,
                                               orientation: .up, targetAspect: 1)
                == CGRect(x: 50, y: 350, width: 100, height: 100))
    }

    @Test func bufferCropRectWithDegenerateImageReturnsImageRect() {
        #expect(SaliencyCropper.bufferCropRect(salientNormalizedRect: .zero, imageSize: .zero,
                                               orientation: .right, targetAspect: 1) == .zero)
    }

    // MARK: End-to-end — orientation
    //
    // Best-effort companion to the pure tests above: it exercises the whole `centeredCrop` plumbing
    // (Vision call, buffer-space crop, orientation re-tag) on a real photo. Whether Vision's
    // saliency model actually produced a map is *printed, not asserted*, because it cannot run in
    // the simulator or in CI — when it falls back to a centre crop this still checks that buffer-
    // space cropping and re-tagging are orientation-consistent, but the strong assertion lives in
    // `mapsAnOrientedSalientBoxOntoTheRawBuffer…` above.

    /// The cropper works in raw buffer space but asks Vision to analyse the *oriented* image, so a
    /// capture tagged `.right` must display the same picture as the already-upright original.
    @Test func cropIsInvariantToTheCaptureOrientationTag() throws {
        let bundle = Bundle(for: SaliencyCropperTestsBundleToken.self)
        let url = try #require(bundle.url(forResource: "car_test", withExtension: "jpg"))
        let photo = try #require(UIImage(contentsOfFile: url.path))
        let capture = try #require(SyntheticCardScene.asRightTaggedCapture(photo))

        let straight = try #require(SaliencyCropper.centeredCrop(photo, targetAspect: 1))
        let tagged = try #require(SaliencyCropper.centeredCrop(capture, targetAspect: 1))
        #expect(tagged.imageOrientation == .right, "the crop should keep the source's tag")

        // Did Vision's saliency actually drive the crop, or did it fall back to the centre? A centre
        // crop is orientation-symmetric by construction, so the invariance check is only strong
        // evidence in the first case.
        let source = try #require(photo.cgImage)
        let centre = SaliencyCropper.centerCropRect(
            imageSize: CGSize(width: source.width, height: source.height), targetAspect: 1
        )
        let straightBuffer = try #require(straight.cgImage)
        let centreCrop = try #require(source.cropping(to: centre.integral))
        let vsCentre = SyntheticCardScene.meanChannelDifference(straightBuffer, centreCrop)
        print("SALIENCY_PATH_EXERCISED=\(vsCentre > 0.01) (vsCentre=\(vsCentre))")

        // Compare what each one *displays*, not the raw buffers.
        let expected = try #require(ImageOrientation.uprighted(straight).cgImage)
        let actual = try #require(ImageOrientation.uprighted(tagged).cgImage)
        #expect(actual.width == expected.width && actual.height == expected.height,
                "\(actual.width)x\(actual.height) vs \(expected.width)x\(expected.height)")
        let difference = SyntheticCardScene.meanChannelDifference(actual, expected)
        #expect(difference < 0.05, "orientation-dependent crop: differ by \(difference)")
    }
}

/// Anchor for `Bundle(for:)` so the test bundle is found by class, not by a hardcoded identifier.
private final class SaliencyCropperTestsBundleToken {}
