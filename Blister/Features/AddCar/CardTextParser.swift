import Foundation

/// One line of text recognised on a card, with how tall it is relative to the image (a proxy for
/// prominence) and the recogniser's confidence. Pure value type so ranking is unit-testable
/// without Vision.
struct RecognizedLine: Equatable, Sendable {
    var text: String
    var heightFraction: CGFloat
    var confidence: Float
}

/// Turns recognised card text into ranked casting-name candidates (v2.2). The casting name is
/// usually the most prominent non-boilerplate text on a blister card, so we rank by height and drop
/// the things a casting name is never: pure numbers / collector numbers, brand names, and the
/// legal/packaging boilerplate. Pure and deterministic — the recogniser feeds it Vision output.
enum CardTextParser {

    static func candidates(from lines: [RecognizedLine], limit: Int = 4) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for line in lines.sorted(by: { rank($0) > rank($1) }) {
            let trimmed = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard isPlausibleCastingName(trimmed) else { continue }
            let key = trimmed.lowercased()
            guard seen.insert(key).inserted else { continue }
            result.append(trimmed)
            if result.count == limit { break }
        }
        return result
    }

    /// Prominence score: height dominates, confidence breaks ties.
    private static func rank(_ line: RecognizedLine) -> CGFloat {
        line.heightFraction + CGFloat(line.confidence) * 0.001
    }

    private static func isPlausibleCastingName(_ text: String) -> Bool {
        guard text.count >= 2 else { return false }
        if isMostlyDigits(text) { return false }
        let lower = text.lowercased()
        if brandTokens.contains(where: { lower.contains($0) }) { return false }
        if legalMarkers.contains(where: { lower.contains($0) }) { return false }
        return true
    }

    /// True when the string is only digits and separators used by collector numbers / years.
    private static func isMostlyDigits(_ text: String) -> Bool {
        let allowed = CharacterSet(charactersIn: "0123456789/-. ")
        return text.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    /// Brand names appear large on cards but are never the casting name. Derived from the model's
    /// own brand list, plus the manufacturer name.
    private static let brandTokens: [String] = {
        var tokens = Brand.allCases
            .filter { $0 != .other }
            .map { $0.displayName.lowercased() }
        tokens.append("mattel")
        return tokens
    }()

    private static let legalMarkers: [String] = [
        "©", "®", "™", "mattel", "assorted", "ages", "made in", "conforms",
        "warning", "choking", "small parts", "not for", "©disney", "www.", "no."
    ]
}
