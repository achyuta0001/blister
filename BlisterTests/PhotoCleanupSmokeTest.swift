#if DEBUG
import Testing
import UIKit
@testable import Blister

/// DEBUG-only smoke test: runs the real cleanup pipeline and writes its stages to the simulator's
/// Documents dir so a human can eyeball the result. Not a correctness assertion (Vision quality
/// varies by device/OS) — a manual inspection harness.
///
/// Two fixtures, because the two isolation paths have different simulator support:
/// - `car_test.jpg`, a loose car with no card → falls through to
///   `VNGenerateForegroundInstanceMaskRequest`, which cannot build an inference context in the
///   simulator (returns nil by design; verify on a device).
/// - a synthetic hand-held card → takes the `CardDetector` path, which is classical CV and **does**
///   run in the simulator, so the card-crop intermediate is real output.
struct PhotoCleanupSmokeTest {

    @Test func liftsCarOntoStudioBackdrop() async throws {
        let bundle = Bundle(for: PhotoCleanupSmokeTestBundleToken.self)
        let url = try #require(bundle.url(forResource: "car_test", withExtension: "jpg"),
                               "car_test.jpg missing from test bundle")
        let original = try #require(UIImage(contentsOfFile: url.path), "could not decode test image")

        let cleaned = await PhotoCleanup.cleaned(original)

        let docs = try documentsDirectory()
        try original.pngData()?.write(to: docs.appendingPathComponent("cleanup_before.png"))
        if let upright = ImageOrientation.uprighted(original).cgImage,
           let card = CardDetector.croppedCard(from: upright),
           let data = UIImage(cgImage: card).pngData() {
            try data.write(to: docs.appendingPathComponent("cleanup_card_crop.png"))
        }
        if let cleaned, let data = cleaned.pngData() {
            try data.write(to: docs.appendingPathComponent("cleanup_after.png"))
        }
        print("PHOTOCLEANUP_DOCS_DIR=\(docs.path)")
        print("PHOTOCLEANUP_RESULT=\(cleaned == nil ? "nil-no-subject" : "composited")")
    }

    /// The carded-and-hand-held case the card-crop path exists for. Runs end to end in the
    /// simulator and writes before / card-crop / after so the hand removal can be seen.
    @Test func cropsAHandHeldCardToTheCardAlone() async throws {
        let scene = SyntheticCardScene.card(degrees: 7, withHands: true)
        let upright = try #require(scene.image.cgImage)

        let card = try #require(CardDetector.croppedCard(from: upright),
                                "card detection failed on the synthetic hand-held card")
        let cleaned = await PhotoCleanup.cleaned(scene.image)

        let docs = try documentsDirectory()
        try scene.image.pngData()?.write(to: docs.appendingPathComponent("carded_before.png"))
        try UIImage(cgImage: card).pngData()?
            .write(to: docs.appendingPathComponent("carded_card_crop.png"))
        if let cleaned, let data = cleaned.pngData() {
            try data.write(to: docs.appendingPathComponent("carded_after.png"))
        }

        let before = SyntheticCardScene.skinFraction(of: upright)
        let after = SyntheticCardScene.skinFraction(of: card)
        print("PHOTOCLEANUP_CARDED_SKIN before=\(before) after=\(after)")
        print("PHOTOCLEANUP_CARDED_RESULT=\(cleaned == nil ? "nil" : "card")")

        #expect(cleaned != nil, "the card path should always produce an image")
        #expect(after < before / 4, "the crop should have removed most of the hand")
    }

    /// The grey-tint fix: a cleaned card is the **card**, not a card pasted onto a studio backdrop.
    ///
    /// The composite fits its subject into a *square* canvas with a 14% margin, so a portrait card
    /// came back 1:1 with roughly 55% of the file given over to a dark grey panel — plus a baked
    /// reflection that ``StudioScene`` then drew a second copy of. Both assertions below fail on that
    /// old output: the aspect was 1.0 and the corners were backdrop.
    @Test func aCleanedCardKeepsItsOwnAspectAndHasNoBackdropMargin() async throws {
        // 420 × 620 card ⇒ aspect ≈ 0.677, comfortably portrait.
        let scene = SyntheticCardScene.card(cardSize: CGSize(width: 420, height: 620),
                                            degrees: 7, withHands: true)
        let cleaned = try #require(await PhotoCleanup.cleaned(scene.image),
                                   "the card path should always produce an image")
        let buffer = try #require(cleaned.cgImage)

        let aspect = CGFloat(buffer.width) / CGFloat(buffer.height)
        print("PHOTOCLEANUP_CARD_ASPECT=\(aspect) (\(buffer.width)x\(buffer.height))")
        #expect(buffer.height > buffer.width, "a portrait card must stay portrait, not go square")
        #expect(abs(aspect - 420.0 / 620.0) < 0.12, "aspect \(aspect) is not the card's")

        // Every corner is card, not backdrop. The composite's pool is clamped to 0.12...0.26
        // brightness and its edge is 0x1C (≈0.11); the synthetic card is 0.93 white.
        let corners = SyntheticCardScene.cornerBrightness(of: buffer)
        print("PHOTOCLEANUP_CARD_CORNERS=\(corners)")
        #expect(corners.count == 4)
        #expect(corners.allSatisfy { $0 > 0.6 },
                "corners \(corners) look like a studio backdrop, not the card")
    }

    /// The loose-car path is unchanged: a lifted cutout still lands on the square studio backdrop.
    ///
    /// Driven through ``PhotoCleanup/studioComposite(lifted:)`` rather than `cleaned(_:)` because the
    /// step above it, `VNGenerateForegroundInstanceMaskRequest`, cannot build an inference context in
    /// the simulator — so an end-to-end run here would only ever prove that Vision is absent.
    @Test func aLiftedSubjectStillGetsTheStudioComposite() throws {
        let subject = try #require(SyntheticCardScene.liftedSubject().cgImage)
        let data = try #require(PhotoCleanup.studioComposite(lifted: subject),
                                "the lift path should still composite")
        let composite = try #require(UIImage(data: data)?.cgImage)

        let docs = try documentsDirectory()
        try data.write(to: docs.appendingPathComponent("lifted_after.png"))

        #expect(composite.width == composite.height, "the composite canvas is square")
        #expect(composite.width > subject.width, "the subject should sit inside a margin")

        // The margin is the point: dark backdrop in every corner, which is exactly what the card
        // path must NOT have.
        let corners = SyntheticCardScene.cornerBrightness(of: composite)
        print("PHOTOCLEANUP_LIFTED_CORNERS=\(corners)")
        #expect(corners.allSatisfy { $0 < 0.35 },
                "corners \(corners) should be studio backdrop")
    }

    private func documentsDirectory() throws -> URL {
        try #require(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first)
    }
}

/// Anchor for `Bundle(for:)` so the test bundle is found by class, not by a hardcoded identifier.
private final class PhotoCleanupSmokeTestBundleToken {}
#endif
