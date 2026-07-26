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
}
