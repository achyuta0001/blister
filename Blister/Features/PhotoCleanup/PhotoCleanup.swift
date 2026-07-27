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
/// Both paths run the same ``ImageEnhancer`` pass, but only the **lift** path composites. A lifted
/// casting is a cutout with an alpha hole around it, so it needs a backdrop to stand on; a
/// perspective-corrected card is already an opaque, edge-to-edge product shot, and dropping it onto
/// the studio canvas would only bake in a grey margin (the square canvas leaves ~55% backdrop around
/// a portrait card) plus a reflection that ``StudioScene`` already draws for itself.
///
/// Fully on-device, Apple frameworks only. Returns `nil` (callers keep the original) when there's no
/// subject or on any failure — it never throws or crashes.
enum PhotoCleanup {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Blister",
                                       category: "PhotoCleanup")

    /// Longest-edge ceiling, in pixels, for anything this pipeline hands back — the card crop in
    /// ``encoded(_:)`` and the studio canvas in ``composite(subject:)``. Bounds both the `Data` that
    /// crosses the `Task.detached` boundary and the image the caller then re-encodes to disk.
    static let maxEncodedEdge: CGFloat = 1600

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

    /// Runs isolation + composite off the main actor. Returns PNG data (`Sendable`) so nothing
    /// non-`Sendable` crosses back to the caller. `cgImage` must already be upright.
    private static func process(cgImage: CGImage) -> Data? {
        if let card = CardDetector.croppedCard(from: cgImage) {
            logger.debug("Cleanup used the card-crop path")
            // Printed card art, not a photographic scene: skip Core Image's auto-adjust chain, whose
            // `CIHighlightShadowAdjust` lifts shadows with uninspected auto parameters and greys the
            // print out (and whose red-eye/face-balance steps are meaningless here).
            let enhanced = ImageEnhancer.enhanced(UIImage(cgImage: card), autoAdjust: false)?.cgImage ?? card
            // No composite — see the type doc. The card *is* the photo.
            return encoded(enhanced)
        }
        logger.debug("No card found — falling back to the subject lift")
        return liftedSubject(cgImage: cgImage)
    }

    /// Fallback isolation for loose (uncarded) castings: Vision's foreground-instance mask.
    ///
    /// Note this cannot be used for carded photos — a hand holding a card is typically a single
    /// connected instance with it, so the mask keeps the hand too (see ``CardDetector``).
    private static func liftedSubject(cgImage: CGImage) -> Data? {
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

        return studioComposite(lifted: subjectCG)
    }

    /// The tail of the lift path: a gentle enhancement pass, then the studio composite.
    ///
    /// Split out and `internal` purely so tests can exercise the loose-car output —
    /// `VNGenerateForegroundInstanceMaskRequest` cannot build an inference context in the simulator,
    /// so nothing above this point can run there (see ``PhotoCleanupSmokeTest``).
    ///
    /// - Parameter lifted: the isolated casting, with a transparent surround.
    static func studioComposite(lifted subject: CGImage) -> Data? {
        // The full auto-adjust chain is right here: this really is a photograph of an object, unlike
        // the flat printed art the card path handles. Fall back to the raw subject if it fails.
        let enhanced = ImageEnhancer.enhanced(UIImage(cgImage: subject))?.cgImage ?? subject
        return composite(subject: enhanced)
    }

    /// Encodes the card crop to `Sendable` data for the trip back across the `Task.detached`
    /// boundary, clamped to ``maxEncodedEdge`` pixels on its **long** side.
    ///
    /// The clamp matters more here than on the composite path, because this is the path most photos
    /// take (a carded casting). A 12MP capture whose card fills ~60% of the frame yields a roughly
    /// 2000×3000 perspective-corrected card; encoding that unclamped means ~6MP of PNG — 10–20MB of
    /// `Data` handed across the boundary purely for `UIImage(data:)` to decode again. 1600px is the
    /// same ceiling ``composite(subject:)`` puts on its canvas.
    ///
    /// The scale is applied to **both** axes, so the card keeps its own aspect. It is deliberately
    /// *not* squared: a portrait card stays portrait (see the type doc, and
    /// `aCleanedCardKeepsItsOwnAspectAndHasNoBackdropMargin`).
    ///
    /// JPEG rather than the composite path's PNG: a perspective-corrected card is opaque, so there is
    /// no alpha to preserve, and ``DocumentsPhotoStore`` re-encodes whatever it is given to lossy
    /// HEIC on the way to disk — a lossless intermediate buys nothing and costs an order of magnitude
    /// in bytes. (The lift path keeps PNG; its subject is a cutout that is composited onto an opaque
    /// canvas, and its canvas was already bounded.)
    ///
    /// `internal` only so tests can pin the output resolution — the clamp went missing once because
    /// nothing did.
    static func encoded(_ image: CGImage) -> Data? {
        let raw = CGSize(width: image.width, height: image.height)
        guard raw.width > 0, raw.height > 0 else { return nil }

        let scale = min(1, maxEncodedEdge / max(raw.width, raw.height))
        let size = CGSize(width: max(1, (raw.width * scale).rounded()),
                          height: max(1, (raw.height * scale).rounded()))

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.jpegData(withCompressionQuality: 0.92) { _ in
            UIImage(cgImage: image).draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// Draws the lifted subject on a dark studio backdrop with a soft contact shadow, auto-framed on
    /// a square canvas. Uses `CleanupGeometry` for the framing math (top-left/bottom-left symmetric
    /// because the placement is centered).
    ///
    /// Only the **subject-lift** path reaches this: it exists to give a cutout with a transparent
    /// surround somewhere to stand. Carded photos return the crop itself (see ``process(cgImage:)``).
    private static func composite(subject: CGImage) -> Data? {
        let subjectSize = CGSize(width: subject.width, height: subject.height)
        guard subjectSize.width > 0, subjectSize.height > 0 else { return nil }

        let rawCanvas = CleanupGeometry.squareCanvas(around: CGRect(origin: .zero, size: subjectSize),
                                                     marginFraction: 0.14)
        let side = min(max(rawCanvas.width, 1), maxEncodedEdge)
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
