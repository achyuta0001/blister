import Testing
import CoreGraphics
@testable import Blister

/// Pure-geometry checks for the photo-cleanup composite. All rects use the bottom-left pixel
/// convention documented on `CleanupGeometry`.
struct CleanupGeometryTests {

    // MARK: paddedCropRect

    @Test func paddingExpandsSubjectBounds() {
        let subject = CGRect(x: 100, y: 100, width: 200, height: 100)
        let image = CGSize(width: 1000, height: 1000)
        let padded = CleanupGeometry.paddedCropRect(subjectBounds: subject,
                                                    imageSize: image,
                                                    paddingFraction: 0.1)
        // pad = 0.1 * max(200, 100) = 20 on every side.
        #expect(padded == CGRect(x: 80, y: 80, width: 240, height: 140))
        #expect(padded.contains(subject))
    }

    @Test func paddingClampsToImageBounds() {
        let subject = CGRect(x: 10, y: 10, width: 980, height: 980)
        let image = CGSize(width: 1000, height: 1000)
        let padded = CleanupGeometry.paddedCropRect(subjectBounds: subject,
                                                    imageSize: image,
                                                    paddingFraction: 0.5)
        #expect(padded == CGRect(origin: .zero, size: image))
        #expect(padded.maxX <= image.width)
        #expect(padded.maxY <= image.height)
    }

    @Test func paddingWithDegenerateSubjectReturnsFullImage() {
        let image = CGSize(width: 640, height: 480)
        let padded = CleanupGeometry.paddedCropRect(subjectBounds: .zero,
                                                    imageSize: image,
                                                    paddingFraction: 0.1)
        #expect(padded == CGRect(origin: .zero, size: image))
    }

    @Test func paddingWithZeroImageDoesNotCrash() {
        let padded = CleanupGeometry.paddedCropRect(subjectBounds: CGRect(x: 0, y: 0, width: 10, height: 10),
                                                    imageSize: .zero,
                                                    paddingFraction: 0.2)
        #expect(padded == .zero)
    }

    // MARK: squareCanvas

    @Test func squareCanvasIsSquareAndContainsRect() {
        let rect = CGRect(x: 0, y: 0, width: 300, height: 150)
        let canvas = CleanupGeometry.squareCanvas(around: rect, marginFraction: 0.1)
        #expect(canvas.width == canvas.height)
        // side = 300 * (1 + 0.2) = 360, which exceeds both subject dimensions.
        #expect(canvas.width == 360)
        #expect(canvas.width >= rect.width)
        #expect(canvas.height >= rect.height)
    }

    @Test func squareCanvasWithDegenerateRectIsZero() {
        #expect(CleanupGeometry.squareCanvas(around: .zero) == .zero)
    }

    // MARK: placement

    @Test func placementIsCentered() {
        let canvas = CGSize(width: 1000, height: 1000)
        let placement = CleanupGeometry.placement(of: CGSize(width: 400, height: 200),
                                                  in: canvas,
                                                  marginFraction: 0.1)
        // Centered means equal margins on opposing sides: left margin == right margin.
        #expect(abs(placement.minX - (canvas.width - placement.maxX)) < 0.0001)
        #expect(abs(placement.midX - canvas.width / 2) < 0.0001)
        #expect(abs(placement.midY - canvas.height / 2) < 0.0001)
    }

    @Test func placementPreservesAspectRatioAndFitsWithMargin() {
        let canvas = CGSize(width: 1000, height: 1000)
        let subject = CGSize(width: 400, height: 200) // 2:1
        let placement = CleanupGeometry.placement(of: subject, in: canvas, marginFraction: 0.1)
        // Aspect ratio preserved.
        #expect(abs(placement.width / placement.height - 2.0) < 0.0001)
        // Fits inside the 80% available box (1 - 2*0.1).
        #expect(placement.width <= canvas.width * 0.8 + 0.0001)
        #expect(placement.height <= canvas.height * 0.8 + 0.0001)
    }

    @Test func placementWithDegenerateInputIsZero() {
        #expect(CleanupGeometry.placement(of: .zero, in: CGSize(width: 100, height: 100)) == .zero)
        #expect(CleanupGeometry.placement(of: CGSize(width: 10, height: 10), in: .zero) == .zero)
    }

    // MARK: contactShadowRect

    @Test func shadowSitsUnderSubjectAndIsCentered() {
        let placement = CGRect(x: 300, y: 400, width: 400, height: 300)
        let canvas = CGSize(width: 1000, height: 1000)
        let shadow = CleanupGeometry.contactShadowRect(under: placement, canvas: canvas)
        // Horizontally centered on the subject.
        #expect(abs(shadow.midX - placement.midX) < 0.0001)
        // Flatter than the subject and narrower.
        #expect(shadow.height < placement.height)
        #expect(shadow.width < placement.width)
        // Centered near the subject's base (bottom-left origin => minY is the base).
        #expect(shadow.midY <= placement.minY + shadow.height)
    }

    @Test func shadowWithDegenerateSubjectIsZero() {
        #expect(CleanupGeometry.contactShadowRect(under: .zero, canvas: CGSize(width: 10, height: 10)) == .zero)
    }
}
