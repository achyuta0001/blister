import CoreGraphics
import Testing
import UIKit
@testable import Blister

/// Pins the **pixel size** of what the card cleanup path hands back, not just its shape.
///
/// `PhotoCleanup.composite(subject:)` has always clamped its canvas to 1600px, but when the card
/// path stopped compositing it grew its own encoder — and that one shipped with no cap. A 12MP
/// capture whose card fills most of the frame produces a roughly 2000×3000 perspective-corrected
/// card, so the *primary* path was PNG-encoding ~6MP, pushing 10–20MB of `Data` across the
/// `Task.detached` boundary and decoding it again on the far side.
///
/// The existing card test asserts the output's **aspect**, which stayed correct throughout — which
/// is exactly why the missing clamp went unnoticed. These assert the resolution.
struct PhotoCleanupEncodingTests {

    /// The clamp itself: a card far over the ceiling comes back at the ceiling, still portrait.
    @Test func anOversizeCardIsClampedToTheLongEdgeCeiling() throws {
        let source = try #require(Self.portrait(width: 2000, height: 3000))

        let data = try #require(PhotoCleanup.encoded(source), "encoding a valid card returned nil")
        let encoded = try #require(UIImage(data: data)?.cgImage, "encoded card would not decode")

        let ceiling = Int(PhotoCleanup.maxEncodedEdge)
        #expect(max(encoded.width, encoded.height) == ceiling,
                "long edge is \(encoded.width)x\(encoded.height), not clamped to \(ceiling)")
        #expect(encoded.height > encoded.width, "a portrait card must not be squared by the clamp")

        // The clamp scales both axes, so the card's own aspect survives it.
        let before = 2000.0 / 3000.0
        let after = Double(encoded.width) / Double(encoded.height)
        #expect(abs(after - before) < 0.01, "aspect drifted from \(before) to \(after)")
    }

    /// A landscape card is clamped on *its* long edge — the ceiling is not a height rule.
    @Test func theCeilingAppliesToWhicheverEdgeIsLonger() throws {
        let source = try #require(Self.portrait(width: 3200, height: 1800))

        let data = try #require(PhotoCleanup.encoded(source))
        let encoded = try #require(UIImage(data: data)?.cgImage)

        #expect(encoded.width == Int(PhotoCleanup.maxEncodedEdge))
        #expect(encoded.width > encoded.height, "a landscape card must stay landscape")
    }

    /// Under the ceiling nothing happens — the clamp must never *upscale* a small card.
    @Test func aCardUnderTheCeilingKeepsItsOwnResolution() throws {
        let source = try #require(Self.portrait(width: 420, height: 620))

        let data = try #require(PhotoCleanup.encoded(source))
        let encoded = try #require(UIImage(data: data)?.cgImage)

        #expect(encoded.width == 420 && encoded.height == 620,
                "small card was resampled to \(encoded.width)x\(encoded.height)")
    }

    /// End to end through the real path, since that is where the size actually reaches the caller:
    /// a big hand-held card capture goes through `CardDetector` and comes back inside the budget.
    ///
    /// `VNDetectRectanglesRequest` is classical CV and does run in the simulator, so this is real
    /// output rather than a stub (unlike the subject-lift path).
    @Test func cleaningABigCardedCaptureStaysInsideThePixelBudget() async throws {
        let scene = SyntheticCardScene.card(imageSize: CGSize(width: 2400, height: 3200),
                                            cardSize: CGSize(width: 1560, height: 2300),
                                            degrees: 6, withHands: true)
        let cleaned = try #require(await PhotoCleanup.cleaned(scene.image),
                                   "the card path should always produce an image")
        let buffer = try #require(cleaned.cgImage)

        let ceiling = Int(PhotoCleanup.maxEncodedEdge)
        #expect(max(buffer.width, buffer.height) <= ceiling,
                "cleaned card is \(buffer.width)x\(buffer.height), over the \(ceiling)px ceiling")
        #expect(buffer.height > buffer.width, "the card should still be portrait")
        // The source card is ~3.6MP; unclamped this used to come straight back at that size.
        #expect(buffer.width * buffer.height < ceiling * ceiling)
    }

    /// A plain opaque rectangle with some interior structure — enough for the renderer to have real
    /// work to do, without depending on card detection.
    private static func portrait(width: Int, height: Int) -> CGImage? {
        let size = CGSize(width: width, height: height)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(white: 0.93, alpha: 1).setFill()
            context.cgContext.fill(CGRect(origin: .zero, size: size))
            UIColor(red: 0.15, green: 0.35, blue: 0.62, alpha: 1).setFill()
            context.cgContext.fill(CGRect(x: size.width * 0.18, y: size.height * 0.30,
                                          width: size.width * 0.64, height: size.height * 0.42))
        }.cgImage
    }
}
