import CoreGraphics
import Testing
import UIKit
@testable import Blister

/// Regression cover for the "cleaned photos come out rotated 90°" bug.
///
/// A phone portrait capture is a **landscape** buffer tagged `.right`. `PhotoCleanup` used to reach
/// straight for `.cgImage`, so every stage analysed sideways pixels and the composite baked the
/// rotation in permanently. These tests pin both the mechanism and the end-to-end behaviour.
struct PhotoCleanupOrientationTests {

    @Test func aTaggedCaptureReallyIsSidewaysInTheBuffer() throws {
        let scene = SyntheticCardScene.card(degrees: 6)
        let capture = try #require(SyntheticCardScene.asRightTaggedCapture(scene.image))
        let buffer = try #require(capture.cgImage)

        #expect(buffer.width == 1200 && buffer.height == 900, "buffer should be landscape")
        #expect(capture.size == CGSize(width: 900, height: 1200), "but it displays portrait")
        #expect(capture.imageOrientation == .right)
    }

    @Test func detectingOnTheRawBufferFindsTheCardLyingOnItsSide() throws {
        // The bug, reproduced at the layer where it originated: read `.cgImage` without honouring
        // the orientation tag and the card measures landscape.
        let scene = SyntheticCardScene.card(degrees: 6)
        let capture = try #require(SyntheticCardScene.asRightTaggedCapture(scene.image))
        let rawBuffer = try #require(capture.cgImage)

        let sideways = try #require(CardDetector.croppedCard(from: rawBuffer))
        #expect(sideways.width > sideways.height, "raw buffer should crop landscape (the bug)")
    }

    @Test func uprightingFirstFindsThePortraitCard() throws {
        let scene = SyntheticCardScene.card(degrees: 6)
        let capture = try #require(SyntheticCardScene.asRightTaggedCapture(scene.image))
        let upright = try #require(ImageOrientation.uprighted(capture).cgImage)

        let card = try #require(CardDetector.croppedCard(from: upright))
        #expect(card.height > card.width, "uprighted buffer should crop portrait (the fix)")
        let aspect = CGFloat(card.width) / CGFloat(card.height)
        #expect(abs(aspect - 420.0 / 620.0) < 0.10, "aspect \(aspect)")
    }

    @Test func cleaningATaggedCaptureMatchesCleaningTheUprightOriginal() async throws {
        let scene = SyntheticCardScene.card(degrees: 6, withHands: true)
        let capture = try #require(SyntheticCardScene.asRightTaggedCapture(scene.image))

        let fromUpright = try #require(await PhotoCleanup.cleaned(scene.image),
                                       "cleanup of the upright original returned nil")
        let fromCapture = try #require(await PhotoCleanup.cleaned(capture),
                                       "cleanup of the tagged capture returned nil")

        #expect(fromCapture.size == fromUpright.size)
        let difference = SyntheticCardScene.meanChannelDifference(
            try #require(fromCapture.cgImage), try #require(fromUpright.cgImage)
        )
        // A 90° rotation of a portrait card on a square canvas scores far above this.
        #expect(difference < 0.03, "composites differ by \(difference) — orientation was dropped")
    }
}
