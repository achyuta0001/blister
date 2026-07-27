import CoreGraphics
import SwiftUI
import Testing
import UIKit
@testable import Blister

/// Proof that the grid **crops** a non-square thumbnail into its square cell instead of stretching
/// it into one.
///
/// `.aspectRatio(1, contentMode: .fill)` looks like a crop but is not: an *explicit* ratio argument
/// overrides the image's own, so a `resizable()` image is squashed to fit the square. It was
/// harmless while every stored thumbnail was square, and stopped being harmless the moment cleaned
/// cards began saving at the card's own ~0.62 aspect (see ``PhotoStoreThumbnailTests``). A 620×1000
/// card rendered horizontally fat.
///
/// The fixture is a four-band portrait image: red on top, then green, then blue, then yellow at the
/// bottom. Filling a square with it keeps only the middle — so a correct card shows **green and
/// blue and neither marker band**, while the squashed version shows all four. Driven through
/// `ImageRenderer` so the real views are what gets measured.
@MainActor
struct GridThumbnailShapeTests {

    @Test func garageCardCropsAPortraitThumbnailRatherThanSquashingIt() throws {
        let filename = try Self.storeBandedPhoto()
        defer { try? DocumentsPhotoStore.shared.delete(filename) }

        let car = Car(castingName: "Band Test", huntStatus: .none, photoFilenames: [filename])
        let rendered = try #require(Self.render(GarageCard(car: car).frame(width: 180)),
                                    "ImageRenderer produced nothing for GarageCard")

        try Self.expectCroppedNotSquashed(rendered, view: "GarageCard")
    }

    @Test func wishlistCardCropsAPortraitThumbnailRatherThanSquashingIt() throws {
        let filename = try Self.storeBandedPhoto()
        defer { try? DocumentsPhotoStore.shared.delete(filename) }

        let car = Car(castingName: "Band Test", huntStatus: .none, status: .wanted,
                      photoFilenames: [filename])
        let rendered = try #require(Self.render(WishlistCard(car: car, onFound: {}).frame(width: 180)),
                                    "ImageRenderer produced nothing for WishlistCard")

        try Self.expectCroppedNotSquashed(rendered, view: "WishlistCard")
    }

    /// A card with no photo falls back to ``TypographicPlaceholder``, which is not an image and so
    /// has no aspect of its own — the square cell must still lay out and draw it.
    @Test func aPhotolessCardStillRendersItsPlaceholder() throws {
        let car = Car(castingName: "'67 Camaro")
        let rendered = try #require(Self.render(GarageCard(car: car).frame(width: 180)),
                                    "ImageRenderer produced nothing for the placeholder card")

        #expect(rendered.width == 180, "card should be its proposed width, got \(rendered.width)")
        // The cell is square, so the card is taller than it is wide once the two captions are added.
        #expect(rendered.height > rendered.width,
                "placeholder cell collapsed: \(rendered.width)x\(rendered.height)")
    }

    // MARK: - Assertions

    private static func expectCroppedNotSquashed(_ rendered: CGImage, view: String) throws {
        let tally = bandTally(of: rendered)
        print("GRID_BANDS_\(view)=\(tally) size=\(rendered.width)x\(rendered.height)")

        #expect(tally.green > 0.05 && tally.blue > 0.05,
                "\(view) did not draw the photo at all: \(tally)")
        // A squashed thumbnail keeps every band; a cropped one keeps only the middle two.
        #expect(tally.red < 0.01,
                "\(view) still shows the source's top band — squashed, not cropped: \(tally)")
        #expect(tally.yellow < 0.01,
                "\(view) still shows the source's bottom band — squashed, not cropped: \(tally)")
    }

    // MARK: - Fixture

    /// Saves the banded fixture through the real store (which is where the cards read from) and
    /// checks it survived the round trip unaltered, so a band tally later can be trusted.
    private static func storeBandedPhoto() throws -> String {
        let store = DocumentsPhotoStore.shared
        let filename = try store.save(bandedSource())
        let thumb = try #require(store.thumbnail(for: filename)?.cgImage,
                                 "no thumbnail written for the banded fixture")
        // If the store ever reshapes it, the band tally below stops meaning anything.
        #expect(thumb.width == 200 && thumb.height == 400,
                "banded fixture was reshaped on the way to disk: \(thumb.width)x\(thumb.height)")
        return filename
    }

    /// 200×400, four horizontal bands. The markers (red, yellow) are inset well clear of the middle
    /// 50% a square crop keeps, so a one-pixel rounding difference can't decide the test.
    private static func bandedSource() -> UIImage {
        let size = CGSize(width: 200, height: 400)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let bands: [(UIColor, CGFloat, CGFloat)] = [
                (.red, 0, 80), (.green, 80, 200), (.blue, 200, 320), (.yellow, 320, 400)
            ]
            for (color, top, bottom) in bands {
                color.setFill()
                context.cgContext.fill(CGRect(x: 0, y: top, width: size.width, height: bottom - top))
            }
        }
    }

    private static func render(_ view: some View) -> CGImage? {
        let renderer = ImageRenderer(content: view.background(DesignTokens.background))
        renderer.scale = 1
        return renderer.uiImage?.cgImage
    }

    // MARK: - Pixel tally

    private struct BandTally: CustomStringConvertible {
        var red = 0.0, green = 0.0, blue = 0.0, yellow = 0.0
        var description: String {
            String(format: "red %.3f green %.3f blue %.3f yellow %.3f", red, green, blue, yellow)
        }
    }

    /// Fraction of `image` occupied by each band colour. Classification is deliberately loose:
    /// the fixture survives a HEIC re-encode, a JPEG thumbnail and a SwiftUI colour-space conversion
    /// before it gets here, so only the dominant channels are trusted. Greys (the card background
    /// and its captions) match nothing.
    private static func bandTally(of image: CGImage) -> BandTally {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return BandTally() }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn: Bool = pixels.withUnsafeMutableBytes { raw in
            guard let context = CGContext(data: raw.baseAddress,
                                          width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: width * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return BandTally() }

        var counts = (red: 0, green: 0, blue: 0, yellow: 0)
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let r = Double(pixels[index]) / 255
            let g = Double(pixels[index + 1]) / 255
            let b = Double(pixels[index + 2]) / 255
            let high = 0.5, low = 0.35
            if r > high, g > high, b < low { counts.yellow += 1 }
            else if r > high, g < low, b < low { counts.red += 1 }
            else if r < low, g > high, b < low { counts.green += 1 }
            else if r < low, g < low, b > high { counts.blue += 1 }
        }

        let total = Double(width * height)
        return BandTally(red: Double(counts.red) / total,
                         green: Double(counts.green) / total,
                         blue: Double(counts.blue) / total,
                         yellow: Double(counts.yellow) / total)
    }
}
