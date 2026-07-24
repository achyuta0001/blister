import UIKit
import Vision
import CoreImage
import os

/// On-device photo cleanup (**frozen contract** — the Add Car / Edit UIs code against `cleaned(_:)`).
/// Lifts the car off its background with Vision and composites it onto a clean studio backdrop with a
/// soft contact shadow, so a messy phone snap reads like a catalogue shot.
///
/// Fully on-device, Apple frameworks only. Returns `nil` (callers keep the original) when there's no
/// subject or on any failure — it never throws or crashes.
enum PhotoCleanup {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Blister",
                                       category: "PhotoCleanup")

    static func cleaned(_ image: UIImage) async -> UIImage? {
        guard let source = image.cgImage else { return nil }
        // CGImage is immutable and thread-safe (Sendable), so it's safe to hand to the detached task.
        let data = await Task.detached(priority: .userInitiated) { () -> Data? in
            process(cgImage: source)
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

        return composite(subject: subjectCG)
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

            // Studio backdrop: near-black with a soft lighter pool in the centre.
            UIColor(red: 0x1C / 255, green: 0x1C / 255, blue: 0x1C / 255, alpha: 1).setFill()
            cg.fill(canvasRect)
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [UIColor(white: 0.20, alpha: 1).cgColor,
                         UIColor(red: 0x1C / 255, green: 0x1C / 255, blue: 0x1C / 255, alpha: 1).cgColor] as CFArray,
                locations: [0, 1]
            ) {
                let center = CGPoint(x: canvas.width / 2, y: canvas.height * 0.42)
                cg.drawRadialGradient(gradient, startCenter: center, startRadius: 0,
                                      endCenter: center, endRadius: canvas.width * 0.62,
                                      options: [.drawsAfterEndLocation])
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
}
