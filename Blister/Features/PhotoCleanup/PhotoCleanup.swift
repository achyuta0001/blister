import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import os

/// On-device photo cleanup (**frozen contract** — the Add Car / Edit UIs code against `cleaned(_:)`).
/// Isolates the casting from its surroundings with Vision and composites it onto a clean studio
/// backdrop with a soft contact shadow, so a messy phone snap reads like a catalogue shot.
///
/// Two isolation strategies, in order:
/// 1. **Card detection** (``CardDetector``) — most photos here are of a *carded* casting held in one
///    hand. Detecting the card's quadrilateral and perspective-correcting it squares the card up and
///    clips to its edges in one step, so the fingers above it and the hand below it fall outside the
///    frame. Subject-lifting cannot do this: a hand gripping a card is usually the *same* connected
///    foreground instance as the card, so no amount of per-instance filtering separates them.
/// 2. **Subject lift** (`VNGenerateForegroundInstanceMaskRequest`) — the fallback for loose
///    (uncarded) castings, where there is no rectangle to find.
///
/// Both paths feed the same ``ImageEnhancer`` pass and the same ``composite(subject:)``, so cleaned
/// photos share one look regardless of which one ran.
///
/// Fully on-device, Apple frameworks only. Returns `nil` (callers keep the original) when there's no
/// subject or on any failure — it never throws or crashes.
enum PhotoCleanup {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Blister",
                                       category: "PhotoCleanup")

    static func cleaned(_ image: UIImage) async -> UIImage? {
        guard let source = image.cgImage else { return nil }
        // CGImage is immutable and thread-safe (Sendable) and `UIImage.Orientation` is a plain enum,
        // so both cross into the detached task safely — `UIImage` itself does not, hence the
        // re-wrap inside. Keeping the upright re-render in here also keeps it off the main actor.
        let orientation = image.imageOrientation
        let data = await Task.detached(priority: .userInitiated) { () -> Data? in
            // Bake the capture rotation into the pixels FIRST. A phone portrait shot is a landscape
            // buffer tagged `.right`, and every stage below reads raw pixels — Vision, Core Image
            // and the composite renderer all ignore `imageOrientation` — so skipping this makes the
            // whole pipeline analyse, and then permanently bake in, a sideways card.
            let wrapped = UIImage(cgImage: source, scale: 1, orientation: orientation)
            guard let upright = ImageOrientation.uprighted(wrapped).cgImage else { return nil }
            return process(cgImage: upright)
        }.value
        guard let data else { return nil }
        return UIImage(data: data)
    }

    /// Runs the Vision lift + composite off the main actor. Returns PNG data (`Sendable`) so nothing
    /// non-`Sendable` crosses back to the caller.
    private static func process(cgImage: CGImage) -> Data? {
        let ciImage = CIImage(cgImage: cgImage)
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        let request = VNGenerateForegroundInstanceMaskRequest()

        do {
            try handler.perform([request])
        } catch {
            logger.error("Foreground mask request failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }

        guard let observation = request.results?.first, !observation.allInstances.isEmpty else {
            // No subject found — caller keeps the original.
            return nil
        }

        let context = CIContext()
        let subjectPixels: CVPixelBuffer
        do {
            subjectPixels = try observation.generateMaskedImage(
                ofInstances: observation.allInstances,
                from: handler,
                croppedToInstancesExtent: true
            )
        } catch {
            logger.error("Masked image generation failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }

        let subjectCI = CIImage(cvPixelBuffer: subjectPixels)
        guard let subjectCG = context.createCGImage(subjectCI, from: subjectCI.extent) else {
            logger.error("Could not rasterise lifted subject")
            return nil
        }

        // Give the lifted subject a gentle enhancement pass so cleaned photos pop; fall back to the
        // raw subject if the pass fails.
        let enhanced = ImageEnhancer.enhanced(UIImage(cgImage: subjectCG))?.cgImage ?? subjectCG

        return composite(subject: enhanced)
    }

    /// Draws the lifted subject on a dark studio backdrop with a soft contact shadow, auto-framed on
    /// a square canvas. Uses `CleanupGeometry` for the framing math (top-left/bottom-left symmetric
    /// because the placement is centered).
    private static func composite(subject: CGImage) -> Data? {
        let subjectSize = CGSize(width: subject.width, height: subject.height)
        guard subjectSize.width > 0, subjectSize.height > 0 else { return nil }

        let rawCanvas = CleanupGeometry.squareCanvas(around: CGRect(origin: .zero, size: subjectSize),
                                                     marginFraction: 0.14)
        let side = min(max(rawCanvas.width, 1), 1600)
        let canvas = CGSize(width: side, height: side)
        let place = CleanupGeometry.placement(of: subjectSize, in: canvas, marginFraction: 0.14)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: canvas, format: format)

        return renderer.pngData { ctx in
            let cg = ctx.cgContext
            let canvasRect = CGRect(origin: .zero, size: canvas)

            // Studio backdrop: near-black, with a soft central pool subtly tinted by the subject's
            // own average colour (desaturated + darkened) so it reads as colour-matched studio light
            // rather than flat grey. Falls back to the old neutral pool if the average can't be read.
            let edge = UIColor(red: 0x1C / 255, green: 0x1C / 255, blue: 0x1C / 255, alpha: 1)
            let pool = studioPoolColor(from: subject) ?? UIColor(white: 0.20, alpha: 1)
            edge.setFill()
            cg.fill(canvasRect)
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [pool.cgColor, edge.cgColor] as CFArray,
                locations: [0, 1]
            ) {
                let center = CGPoint(x: canvas.width / 2, y: canvas.height * 0.42)
                cg.drawRadialGradient(gradient, startCenter: center, startRadius: 0,
                                      endCenter: center, endRadius: canvas.width * 0.62,
                                      options: [.drawsAfterEndLocation])
            }

            // Soft mirror reflection beneath the subject (product-shot style). Kept short + faded so a
            // tall carded product's reflection stays subtle and never overflows the square canvas.
            let reflection = CleanupGeometry.reflectionRect(under: place, canvas: canvas,
                                                            heightFraction: 0.22)
            if reflection.height > 1 {
                cg.saveGState()
                cg.beginTransparencyLayer(auxiliaryInfo: nil)
                cg.clip(to: reflection)
                // Mirror the subject across the base line (y = place.maxY) so its bottom edge meets
                // the real base; the clip keeps only the short top slice.
                cg.saveGState()
                cg.translateBy(x: 0, y: place.maxY * 2)
                cg.scaleBy(x: 1, y: -1)
                UIImage(cgImage: subject).draw(in: place)
                cg.restoreGState()
                // Fade the reflection out top-to-bottom (strongest at the base).
                cg.setBlendMode(.destinationIn)
                if let fade = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: [UIColor(white: 1, alpha: 0.35).cgColor,
                             UIColor(white: 1, alpha: 0).cgColor] as CFArray,
                    locations: [0, 1]
                ) {
                    cg.drawLinearGradient(fade,
                                          start: CGPoint(x: reflection.midX, y: reflection.minY),
                                          end: CGPoint(x: reflection.midX, y: reflection.maxY),
                                          options: [])
                }
                cg.endTransparencyLayer()
                cg.restoreGState()
            }

            // Soft contact shadow under the subject (UIKit top-left space: base is `place.maxY`).
            let shadowW = place.width * 0.9
            let shadowH = max(2, place.width * 0.10)
            let shadowRect = CGRect(x: place.midX - shadowW / 2,
                                    y: place.maxY - shadowH * 0.45,
                                    width: shadowW, height: shadowH)
            cg.saveGState()
            cg.addEllipse(in: shadowRect)
            cg.clip()
            if let shadow = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [UIColor(white: 0, alpha: 0.55).cgColor,
                         UIColor(white: 0, alpha: 0).cgColor] as CFArray,
                locations: [0, 1]
            ) {
                let c = CGPoint(x: shadowRect.midX, y: shadowRect.midY)
                cg.drawRadialGradient(shadow, startCenter: c, startRadius: 0,
                                      endCenter: c, endRadius: shadowW / 2, options: [])
            }
            cg.restoreGState()

            // The lifted subject.
            UIImage(cgImage: subject).draw(in: place)
        }
    }

    /// A low-saturation, mostly-dark colour derived from the subject for the backdrop pool: a hint of
    /// the casting's colour, never a spotlight. `nil` when the average can't be read (caller falls
    /// back to a neutral grey).
    private static func studioPoolColor(from subject: CGImage) -> UIColor? {
        guard let average = averageColor(of: subject) else { return nil }
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        guard average.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return nil
        }
        let pooledSaturation = min(saturation * 0.4, 0.35)
        let pooledBrightness = min(max(brightness, 0.12), 0.26)
        return UIColor(hue: hue, saturation: pooledSaturation, brightness: pooledBrightness, alpha: 1)
    }

    /// Average colour of the lifted subject via `CIAreaAverage`. The subject has a transparent
    /// background, so the rendered (premultiplied) average is un-premultiplied to recover the
    /// subject's own colour instead of a value dragged toward black by the empty pixels.
    private static func averageColor(of image: CGImage) -> UIColor? {
        let ciImage = CIImage(cgImage: image)
        let filter = CIFilter.areaAverage()
        filter.inputImage = ciImage
        filter.extent = ciImage.extent
        guard let output = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext()
        context.render(output,
                       toBitmap: &bitmap,
                       rowBytes: 4,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8,
                       colorSpace: CGColorSpaceCreateDeviceRGB())

        let alpha = CGFloat(bitmap[3]) / 255
        guard alpha > 0.01 else { return nil }
        let red = min(CGFloat(bitmap[0]) / 255 / alpha, 1)
        let green = min(CGFloat(bitmap[1]) / 255 / alpha, 1)
        let blue = min(CGFloat(bitmap[2]) / 255 / alpha, 1)
        return UIColor(red: red, green: green, blue: blue, alpha: 1)
    }
}
