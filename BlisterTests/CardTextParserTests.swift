import Testing
import Foundation
@testable import Blister

struct CardTextParserTests {

    private func line(_ text: String, _ height: CGFloat, _ confidence: Float = 0.9) -> RecognizedLine {
        RecognizedLine(text: text, heightFraction: height, confidence: confidence)
    }

    @Test func ranksMoreProminentLinesFirst() {
        let lines = [
            line("Spectraflame Blue", 0.05),
            line("Camaro", 0.20),
            line("Japan Historics", 0.08)
        ]
        let candidates = CardTextParser.candidates(from: lines)
        #expect(candidates.first == "Camaro")
    }

    @Test func dropsCollectorNumbersAndPureDigits() {
        let lines = [
            line("142/250", 0.25),
            line("2020", 0.24),
            line("Datsun 240Z", 0.18)
        ]
        let candidates = CardTextParser.candidates(from: lines)
        #expect(candidates == ["Datsun 240Z"])
    }

    @Test func dropsBrandNames() {
        let lines = [
            line("HOT WHEELS", 0.30),
            line("MATCHBOX", 0.28),
            line("Nissan Skyline", 0.20)
        ]
        let candidates = CardTextParser.candidates(from: lines)
        #expect(candidates.first == "Nissan Skyline")
        #expect(!candidates.contains { $0.lowercased().contains("hot wheels") })
    }

    @Test func dropsLegalAndCopyrightLines() {
        let lines = [
            line("© 2020 Mattel", 0.22),
            line("MADE IN MALAYSIA", 0.20),
            line("AGES 3+", 0.19),
            line("Toyota Supra", 0.18)
        ]
        let candidates = CardTextParser.candidates(from: lines)
        #expect(candidates == ["Toyota Supra"])
    }

    @Test func trimsWhitespaceAndDedupesCaseInsensitively() {
        let lines = [
            line("  Corvette  ", 0.20),
            line("corvette", 0.10),
            line("CORVETTE", 0.05)
        ]
        let candidates = CardTextParser.candidates(from: lines)
        #expect(candidates == ["Corvette"])
    }

    @Test func limitsToRequestedCount() {
        let lines = (0..<10).map { line("Casting \($0)", CGFloat(10 - $0) / 10) }
        let candidates = CardTextParser.candidates(from: lines, limit: 3)
        #expect(candidates.count == 3)
    }

    @Test func returnsEmptyWhenNothingUsable() {
        let lines = [line("©", 0.3), line("99", 0.2), line("HOT WHEELS", 0.25)]
        #expect(CardTextParser.candidates(from: lines).isEmpty)
    }
}
