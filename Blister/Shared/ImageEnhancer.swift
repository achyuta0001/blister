import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit
import os

/// On-device "pop" pass built on Core Image. Optionally applies Core Image's suggested auto
/// adjustments (exposure / contrast / tone / white-balance), then a gentle punch — a little more
/// saturation and contrast, a touch of luminance sharpening, and light noise reduction — so a flat
/// phone snap reads more like a catalogue shot.
///
/// Kept deliberately GENTLE: most photos are of *carded* castings behind a clear plastic bubble, so
/// aggressive sharpening or contrast/highlight boosts would only amplify specular glare and blow out
/// the plastic. The goal is modest exposure/WB normalisation plus mild saturation.
///
/// Pure and side-effect free — safe to call off the main actor (the only UIKit touch is
/// `UIImage(cgImage:)`, which is thread-safe). Returns `nil` on any failure and preserves the source
/// orientation and pixel size.
enum ImageEnhancer {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Blister",
                                       category: "ImageEnhancer")

    /// Shared context — `CIContext` is expensive to build and is safe to reuse across threads.
    private static let context = CIContext()

    /// - Parameters:
    ///   - image: the source image; its scale and orientation are preserved.
    ///   - autoAdjust: run Core Image's suggested auto-adjustment chain before the tuned steps.
    ///     Leave `true` for photographic subjects. Pass `false` for **flat printed art** such as a
    ///     perspective-corrected blister card: on iOS that chain is red-eye correction, face balance,
    ///     vibrance, a tone curve and `CIHighlightShadowAdjust`. The first two are meaningless on a
    ///     card, and the last lifts shadows by an auto-computed amount nothing here inspects — it is
    ///     the one uncontrolled wash-out lever in the pipeline, and greys out card art.
    static func enhanced(_ image: UIImage, autoAdjust: Bool = true) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let source = CIImage(cgImage: cgImage)
        var working = source

        // 1. Auto exposure / contrast / tone / white-balance suggested by Core Image.
        if autoAdjust {
            for filter in working.autoAdjustmentFilters() {
                filter.setValue(working, forKey: kCIInputImageKey)
                if let output = filter.outputImage { working = output }
            }
        }

        // 2. Gentle punch: a hair more saturation, barely any extra contrast (contrast bumps push
        //    plastic-bubble highlights toward blowout, so keep it minimal).
        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = working
        colorControls.saturation = 1.06
        colorControls.contrast = 1.02
        colorControls.brightness = 0
        if let output = colorControls.outputImage { working = output }

        // 3. Mild luminance sharpening — enough to crisp the casting, not enough to ring the glare.
        let sharpen = CIFilter.sharpenLuminance()
        sharpen.inputImage = working
        sharpen.sharpness = 0.25
        if let output = sharpen.outputImage { working = output }

        // 4. Light noise reduction so the punch doesn't amplify grain.
        let denoise = CIFilter.noiseReduction()
        denoise.inputImage = working
        denoise.noiseLevel = 0.02
        denoise.sharpness = 0.4
        if let output = denoise.outputImage { working = output }

        // Render at the ORIGINAL extent so the pixel size is preserved; some auto-adjust filters can
        // shift the extent, so clamp back to the source rect.
        let renderRect = source.extent
        guard !renderRect.isInfinite, !renderRect.isEmpty,
              let rendered = context.createCGImage(working, from: renderRect) else {
            logger.error("Image enhancement failed to render")
            return nil
        }

        return UIImage(cgImage: rendered, scale: image.scale, orientation: image.imageOrientation)
    }
}
