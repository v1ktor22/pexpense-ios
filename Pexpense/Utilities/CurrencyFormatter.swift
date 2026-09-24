//
//  CurrencyFormatter.swift
//  Pexpense
//

import Foundation

/// Presentation-only formatting of monetary amounts.
///
/// Amounts travel from the API as an integer number of minor units (centimes).
/// They are carried and computed as `Int` and are never converted to a binary
/// floating point type. See `docs/architecture/adr-0004`.
nonisolated enum CurrencyFormatter {

    /// Currencies supported by the product. CHF is the default, EUR the secondary.
    enum Currency: String, Sendable, CaseIterable {
        case chf = "CHF"
        case eur = "EUR"

        /// Symbol used when composing the display string.
        var symbol: String {
            switch self {
            case .chf: "CHF"
            case .eur: "€"
            }
        }
    }

    /// Locale driving decimal and grouping conventions.
    static let locale = Locale(identifier: "de-CH")

    /// Grouping separator pinned to `U+0027` (APOSTROPHE).
    ///
    /// ICU has been observed to emit `U+2019` (RIGHT SINGLE QUOTATION MARK)
    /// instead, depending on the version. Pinning it explicitly keeps the
    /// canonical output stable. `CurrencyFormatterTests` asserts the code point.
    static let groupingSeparator = "\u{0027}"

    /// Formats an integer amount of minor units for display.
    ///
    /// - Parameters:
    ///   - minorUnits: amount in centimes, e.g. `189_000` for `CHF 1'890.00`.
    ///   - currency: currency to compose with the value.
    /// - Returns: symbol and value, e.g. `CHF 1'890.00` or `€ 68.50`.
    static func string(fromMinorUnits minorUnits: Int, currency: Currency) -> String {
        "\(currency.symbol) \(decimalString(fromMinorUnits: minorUnits))"
    }

    /// Formats an integer amount of minor units as a plain decimal string.
    ///
    /// The integer and fractional parts are derived with integer arithmetic, so
    /// no rounding through `Double` can occur.
    static func decimalString(fromMinorUnits minorUnits: Int) -> String {
        let units = minorUnits / 100
        let centimes = abs(minorUnits % 100)

        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = groupingSeparator
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0

        let grouped = formatter.string(from: NSNumber(value: units)) ?? "\(units)"
        let fraction = centimes < 10 ? "0\(centimes)" : "\(centimes)"
        let separator = formatter.decimalSeparator ?? "."

        return "\(grouped)\(separator)\(fraction)"
    }
}