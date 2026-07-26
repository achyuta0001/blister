import UIKit
import Vision
import os

/// Recognises casting-name candidates from a card photo using on-device Vision (v2.2). **Frozen
/// contract** — the Add Car UI codes against `recognize(_:)`; the implementation lives here.
///
/// Stateless and `Sendable` so it can be called from a SwiftUI `Task`. On-device only, zero
/// third-party dependencies.
struct CardTextRecognizer: Sendable {

    private static let logger = Logger(subsystem: "Blister", category: "CardTextRecognizer")

    /// Returns ranked casting-name candidates for the image (best first), or `[]` if none / on
    /// failure. Never throws — OCR is a hint, so a failure just yields no suggestions.
    func recognize(_ image: UIImage) async -> [String] {
        // `CGImage` is immutable and thread-safe, so it can cross the actor/thread boundary that the
        // Vision async request performs internally without introducing a data race.
        guard let cgImage = image.cgImage else { return [] }
        // `cgImage` is the *raw* buffer: a phone portrait shot is landscape pixels tagged `.right`,
        // and Vision would otherwise try to read a sideways card. Hand it the EXIF orientation
        // instead of re-rendering — text recognition only needs to know which way is up, and the
        // bounding boxes below are used as relative size hints, not absolute positions.
        let orientation = ImageOrientation.cgOrientation(image.imageOrientation)

        do {
            var request = RecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let observations = try await request.perform(on: cgImage, orientation: orientation)

            let lines: [RecognizedLine] = observations.compactMap { observation in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                // `boundingBox` is normalised (0–1); its height is a proxy for how large the text is.
                let height = observation.boundingBox.cgRect.height
                return RecognizedLine(
                    text: candidate.string,
                    heightFraction: height,
                    confidence: candidate.confidence
                )
            }

            return CardTextParser.candidates(from: lines)
        } catch {
            Self.logger.debug("Text recognition failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }
}
