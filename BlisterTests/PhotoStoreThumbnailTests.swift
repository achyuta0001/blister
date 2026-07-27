import CoreGraphics
import Testing
import UIKit
@testable import Blister

/// Pins the **shape** of a stored thumbnail.
///
/// Grid thumbnails used to be square by construction: cleanup emitted a 1600×1600 composite and the
/// saliency fallback forced a square crop. Both guarantees are gone — a cleaned card now saves at
/// the card's own ~0.62 aspect and `SaliencyCropper.fallbackCropRect` keeps the whole image — but
/// nothing asserted it either way, so the change was invisible to the suite while it quietly broke
/// the grid (`GarageCard` / `WishlistCard` were stretching, not cropping; see
/// ``GridThumbnailShapeTests``).
///
/// These are deterministic in the simulator despite `SaliencyCropper` calling Vision: the fixture is
/// a card that fills its own frame, so the salient path (if the model could run) unions to the whole
/// image and `cropRect` clamps back to it — the same rect the fallback returns.
struct PhotoStoreThumbnailTests {

    @Test func aPortraitCleanedCardIsStoredAsAPortraitThumbnail() async throws {
        let scene = SyntheticCardScene.card(cardSize: CGSize(width: 420, height: 620),
                                            degrees: 7, withHands: true)
        let cleaned = try #require(await PhotoCleanup.cleaned(scene.image),
                                   "the card path should always produce an image")
        let cleanedBuffer = try #require(cleaned.cgImage)
        let cleanedAspect = Double(cleanedBuffer.width) / Double(cleanedBuffer.height)

        let store = DocumentsPhotoStore.shared
        let filename = try store.save(cleaned)
        defer { try? store.delete(filename) }

        let thumbnail = try #require(store.thumbnail(for: filename), "no thumbnail was written")
        let thumb = try #require(thumbnail.cgImage)
        let thumbAspect = Double(thumb.width) / Double(thumb.height)
        print("PHOTOSTORE_THUMB=\(thumb.width)x\(thumb.height) cleaned=\(cleanedAspect)")

        // Not square: the grid's square cell has to *crop* this, which is the whole point of
        // ``GridThumbnailShapeTests``. If this ever goes square again that test stops meaning
        // anything, so the premise is pinned here.
        #expect(thumb.width != thumb.height,
                "the stored thumb is square (\(thumb.width)x\(thumb.height))")
        #expect(thumb.height > thumb.width, "a portrait card must store as a portrait thumb")
        #expect(abs(thumbAspect - cleanedAspect) < 0.03,
                "the store changed the aspect: \(cleanedAspect) in, \(thumbAspect) out")

        // Spec §9: 400px on the longest edge.
        #expect(max(thumb.width, thumb.height) == 400,
                "thumb long edge is \(max(thumb.width, thumb.height)), not 400")
    }

    /// The complement: a square source still stores square, so the assertion above is about the
    /// *source's* shape being preserved rather than about the store having flipped to "always tall".
    @Test func aSquareCompositeIsStoredAsASquareThumbnail() throws {
        let subject = try #require(SyntheticCardScene.liftedSubject().cgImage)
        let data = try #require(PhotoCleanup.studioComposite(lifted: subject))
        let composite = try #require(UIImage(data: data))

        let store = DocumentsPhotoStore.shared
        let filename = try store.save(composite)
        defer { try? store.delete(filename) }

        let thumb = try #require(store.thumbnail(for: filename)?.cgImage)
        #expect(thumb.width == thumb.height,
                "square composite stored as \(thumb.width)x\(thumb.height)")
        #expect(thumb.width == 400)
    }

    /// Only relative filenames leave the store — never a path, and never image data (spec §3).
    @Test func saveReturnsARelativeFilename() throws {
        let store = DocumentsPhotoStore.shared
        let filename = try store.save(SyntheticCardScene.blank(size: CGSize(width: 300, height: 300)))
        defer { try? store.delete(filename) }

        #expect(!filename.contains("/"), "\(filename) is a path, not a relative filename")
        #expect(filename.hasSuffix(".heic"))
        #expect(store.fullImage(for: filename) != nil)
    }
}
