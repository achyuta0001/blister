import CoreGraphics
import Testing
import UIKit
@testable import Blister

/// `VNDetectRectanglesRequest` is a classical (non-inference) detector, so unlike the
/// foreground-instance mask it **does** run in the simulator — these exercise the real Vision path,
/// not a stub.
struct CardDetectorTests {

    // MARK: Detection

    @Test func findsTheCornersOfATiltedCard() throws {
        let scene = SyntheticCardScene.card(degrees: 8)
        let buffer = try #require(scene.image.cgImage)
        let quad = try #require(CardDetector.detect(in: buffer), "no rectangle detected")

        // `CardDetector` reports bottom-left-origin pixels; the scene reports top-left.
        let height = CGFloat(buffer.height)
        let expected = scene.corners.map { CGPoint(x: $0.x, y: height - $0.y) }
        let found = [quad.topLeft, quad.topRight, quad.bottomRight, quad.bottomLeft]

        for (index, corner) in found.enumerated() {
            let target = expected[index]
            let delta = hypot(corner.x - target.x, corner.y - target.y)
            #expect(delta < 16, "corner \(index) off by \(delta): got \(corner), want \(target)")
        }
    }

    @Test func findsAnUprightCardToo() throws {
        let scene = SyntheticCardScene.card(degrees: 0)
        let buffer = try #require(scene.image.cgImage)
        let quad = try #require(CardDetector.detect(in: buffer), "no rectangle detected")
        let bounds = quad.boundingBox
        #expect(abs(bounds.width - 420) < 16, "width \(bounds.width)")
        #expect(abs(bounds.height - 620) < 16, "height \(bounds.height)")
    }

    @Test func returnsNilForAFlatTexturelessImage() throws {
        let buffer = try #require(SyntheticCardScene.blank().cgImage)
        #expect(CardDetector.detect(in: buffer) == nil)
        #expect(CardDetector.croppedCard(from: buffer) == nil)
    }

    // MARK: Cropping

    @Test func croppedCardIsDeskewedToTheCardsOwnAspect() throws {
        let scene = SyntheticCardScene.card(degrees: 10)
        let buffer = try #require(scene.image.cgImage)
        let cropped = try #require(CardDetector.croppedCard(from: buffer), "no card crop produced")

        // The card is 420×620 (0.677); the crop adds only the small margin, so the aspect holds and
        // the output is much smaller than the 900×1200 source.
        let aspect = CGFloat(cropped.width) / CGFloat(cropped.height)
        #expect(abs(aspect - 420.0 / 620.0) < 0.10, "aspect \(aspect)")
        #expect(cropped.width < 520, "crop is not tight: \(cropped.width)")
        #expect(cropped.height < 720, "crop is not tight: \(cropped.height)")
    }

    /// The point of the whole card-crop path: a hand holding the card is gone from the output.
    @Test func croppingRemovesTheHandHoldingTheCard() throws {
        let scene = SyntheticCardScene.card(degrees: 6, withHands: true)
        let buffer = try #require(scene.image.cgImage)

        let before = SyntheticCardScene.skinFraction(of: buffer)
        #expect(before > 0.03, "the fixture should actually contain a hand, got \(before)")

        let cropped = try #require(CardDetector.croppedCard(from: buffer), "no card crop produced")
        let after = SyntheticCardScene.skinFraction(of: cropped)
        #expect(after < 0.005, "hand survived the crop: \(after) of the cropped pixels are skin")
    }

    // MARK: Padding math (pure)

    @Test func paddingGrowsTheQuadWithoutLeavingTheImage() {
        let imageSize = CGSize(width: 900, height: 1200)
        let quad = CardDetector.Quad(topLeft: CGPoint(x: 240, y: 910),
                                     topRight: CGPoint(x: 660, y: 910),
                                     bottomLeft: CGPoint(x: 240, y: 290),
                                     bottomRight: CGPoint(x: 660, y: 290))
        let padded = CardDetector.padded(quad, imageSize: imageSize, paddingFraction: 0.02)

        #expect(padded.boundingBox.width > quad.boundingBox.width)
        #expect(padded.boundingBox.height > quad.boundingBox.height)
        // Still comfortably tighter than the frame, and entirely inside it.
        #expect(padded.boundingBox.width < 520)
        for corner in padded.corners {
            #expect(corner.x >= 0 && corner.x <= imageSize.width)
            #expect(corner.y >= 0 && corner.y <= imageSize.height)
        }
    }

    @Test func paddingClampsAQuadThatAlreadyFillsTheFrame() {
        let imageSize = CGSize(width: 400, height: 600)
        let quad = CardDetector.Quad(topLeft: CGPoint(x: 0, y: 600),
                                     topRight: CGPoint(x: 400, y: 600),
                                     bottomLeft: CGPoint(x: 0, y: 0),
                                     bottomRight: CGPoint(x: 400, y: 0))
        let padded = CardDetector.padded(quad, imageSize: imageSize, paddingFraction: 0.05)
        for corner in padded.corners {
            #expect(corner.x >= 0 && corner.x <= imageSize.width)
            #expect(corner.y >= 0 && corner.y <= imageSize.height)
        }
    }

    @Test func quadAreaUsesTheEnclosedShapeNotItsBoundingBox() {
        // A 45°-tilted 100×100 square: bounding box ≈ 141×141 (≈20000), true area 10000.
        let corners = SyntheticCardScene.tiltedCorners(center: CGPoint(x: 500, y: 500),
                                                       size: CGSize(width: 100, height: 100),
                                                       degrees: 45)
        let quad = CardDetector.Quad(topLeft: corners[0], topRight: corners[1],
                                     bottomLeft: corners[3], bottomRight: corners[2])
        #expect(abs(quad.area - 10_000) < 1)
        #expect(quad.boundingBox.width > 140)
    }
}
