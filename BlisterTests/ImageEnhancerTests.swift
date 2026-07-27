import CoreImage
import Testing
import UIKit
@testable import Blister

/// Checks the Core Image enhancement pass returns a usable image at the source pixel size.
struct ImageEnhancerTests {

    /// Renders a simple gradient so the auto-adjust filters have real tonal range to work on.
    private func sampleImage(width: CGFloat, height: CGFloat) -> UIImage {
        let size = CGSize(width: width, height: height)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            let colors = [UIColor(red: 0.1, green: 0.2, blue: 0.4, alpha: 1).cgColor,
                          UIColor(red: 0.9, green: 0.7, blue: 0.3, alpha: 1).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: colors, locations: [0, 1]) {
                cg.drawLinearGradient(gradient, start: .zero,
                                      end: CGPoint(x: width, y: height), options: [])
            }
        }
    }

    /// Flat printed art with a deep shadow block — the shape of a blister card, and the input
    /// `CIHighlightShadowAdjust` reaches for hardest.
    private func printedArtImage(width: CGFloat, height: CGFloat) -> UIImage {
        let size = CGSize(width: width, height: height)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            UIColor(white: 0.93, alpha: 1).setFill()
            cg.fill(CGRect(origin: .zero, size: size))
            UIColor(red: 0.05, green: 0.07, blue: 0.10, alpha: 1).setFill()
            cg.fill(CGRect(x: 0, y: height * 0.55, width: width, height: height * 0.45))
        }
    }

    @Test func enhancedPreservesPixelDimensions() throws {
        let original = sampleImage(width: 120, height: 80)
        let enhanced = try #require(ImageEnhancer.enhanced(original),
                                    "a valid image should enhance to a non-nil result")
        let source = try #require(original.cgImage)
        let result = try #require(enhanced.cgImage)
        #expect(result.width == source.width)
        #expect(result.height == source.height)
    }

    @Test func skippingAutoAdjustPreservesPixelDimensions() throws {
        let original = sampleImage(width: 120, height: 80)
        let enhanced = try #require(ImageEnhancer.enhanced(original, autoAdjust: false))
        let source = try #require(original.cgImage)
        let result = try #require(enhanced.cgImage)
        #expect(result.width == source.width)
        #expect(result.height == source.height)
    }

    /// `autoAdjust: false` is the card path's defence against the grey wash.
    ///
    /// On iOS `autoAdjustmentFilters()` hands back red-eye correction, face balance, vibrance, a tone
    /// curve and `CIHighlightShadowAdjust`. The first two mean nothing on printed card art, and the
    /// last lifts shadows by an amount nothing in the pipeline chooses or inspects — it is the one
    /// uncontrolled wash-out lever. Skipping the chain must leave the darks where they were.
    @Test func skippingAutoAdjustDoesNotLiftShadows() throws {
        let original = printedArtImage(width: 240, height: 360)
        let source = try #require(original.cgImage)

        let autoFilters = CIImage(cgImage: source).autoAdjustmentFilters().map(\.name)
        print("IMAGEENHANCER_AUTO_FILTERS=\(autoFilters)")
        #expect(!autoFilters.isEmpty, "premise: iOS suggests an auto-adjust chain for this fixture")

        let auto = try #require(ImageEnhancer.enhanced(original)?.cgImage)
        let skipped = try #require(ImageEnhancer.enhanced(original, autoAdjust: false)?.cgImage)

        // Sample the shadow block: the bottom corners of the art, well inside the dark region.
        let autoShadow = try #require(SyntheticCardScene.cornerBrightness(of: auto, insetFraction: 0.12)
                                        .suffix(2).max())
        let skippedShadow = try #require(SyntheticCardScene.cornerBrightness(of: skipped,
                                                                             insetFraction: 0.12)
                                        .suffix(2).max())
        print("IMAGEENHANCER_SHADOW auto=\(autoShadow) skipped=\(skippedShadow)")

        #expect(skippedShadow <= autoShadow + 0.002,
                "skipping the auto chain must not brighten the darks (auto=\(autoShadow), skipped=\(skippedShadow))")

        // The tuned steps still run either way, so the skipped pass is a real enhancement, not a copy.
        let difference = SyntheticCardScene.meanChannelDifference(skipped, source)
        print("IMAGEENHANCER_SKIPPED_VS_SOURCE=\(difference)")
    }
}
