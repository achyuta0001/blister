import Foundation

/// INR currency formatting via `Decimal` + `FormatStyle` — never string interpolation (spec §9).
enum CurrencyFormat {
    /// Formats an amount as INR, e.g. `₹1,299`. Fraction digits collapse to whole rupees by
    /// default since die-cast prices are rarely sub-rupee.
    static func inr(_ amount: Decimal, fractionDigits: Int = 0) -> String {
        amount.formatted(
            .currency(code: "INR")
                .precision(.fractionLength(fractionDigits))
        )
    }

    /// Formats an optional amount, returning an em dash when absent.
    static func inr(_ amount: Decimal?, fractionDigits: Int = 0) -> String {
        guard let amount else { return "—" }
        return inr(amount, fractionDigits: fractionDigits)
    }
}
