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

    @Test func enhancedPreservesPixelDimensions() throws {
        let original = sampleImage(width: 120, height: 80)
        let enhanced = try #require(ImageEnhancer.enhanced(original),
                                    "a valid image should enhance to a non-nil result")
        let source = try #require(original.cgImage)
        let result = try #require(enhanced.cgImage)
        #expect(result.width == source.width)
        #expect(result.height == source.height)
    }
}
