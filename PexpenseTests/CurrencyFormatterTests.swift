//
//  CurrencyFormatterTests.swift
//  PexpenseTests
//

import Foundation
import Testing
@testable import Pexpense

@Suite("CurrencyFormatter")
struct CurrencyFormatterTests {

    // MARK: - Canonical output

    @Test("Formats the canonical CHF amount")
    func canonicalCHFAmount() {
        #expect(
            CurrencyFormatter.string(fromMinorUnits: 189_000, currency: .chf)
                == "CHF 1'890.00"
        )
    }

    @Test("Formats the canonical EUR amount")
    func canonicalEURAmount() {
        #expect(
            CurrencyFormatter.string(fromMinorUnits: 6_850, currency: .eur)
                == "€ 68.50"
        )
    }

    // MARK: - Grouping separator code point

    /// The separator must be `U+0027` (APOSTROPHE), never `U+2019`
    /// (RIGHT SINGLE QUOTATION MARK). ICU has been observed to vary.
    @Test("Grouping separator is U+0027, not U+2019")
    func groupingSeparatorCodePoint() {
        let output = CurrencyFormatter.string(fromMinorUnits: 189_000, currency: .chf)
        let separator = String(
            output.unicodeScalars.filter { $0.value == 0x27 || $0.value == 0x2019 }
        )

        #expect(
            separator.unicodeScalars.first?.value == 0x27,
            "Expected U+0027; got \(Self.codePoints(of: output))"
        )
    }

    @Test("Pinned grouping separator constant is U+0027")
    func pinnedGroupingSeparatorConstant() {
        #expect(CurrencyFormatter.groupingSeparator.unicodeScalars.first?.value == 0x27)
    }

    // MARK: - Integer arithmetic, no floating point

    @Test("Formats sub-unit amounts without rounding")
    func subUnitAmounts() {
        #expect(CurrencyFormatter.string(fromMinorUnits: 0, currency: .chf) == "CHF 0.00")
        #expect(CurrencyFormatter.string(fromMinorUnits: 5, currency: .chf) == "CHF 0.05")
        #expect(CurrencyFormatter.string(fromMinorUnits: 99, currency: .chf) == "CHF 0.99")
        #expect(CurrencyFormatter.string(fromMinorUnits: 100, currency: .chf) == "CHF 1.00")
    }

    @Test("Groups every three digits")
    func groupsEveryThreeDigits() {
        #expect(
            CurrencyFormatter.string(fromMinorUnits: 123_456_789, currency: .chf)
                == "CHF 1'234'567.89"
        )
    }

    @Test("Formats negative amounts")
    func negativeAmounts() {
        #expect(
            CurrencyFormatter.string(fromMinorUnits: -189_000, currency: .chf)
                == "CHF -1'890.00"
        )
    }

    // MARK: - Helpers

    private static func codePoints(of string: String) -> String {
        string.unicodeScalars
            .map { String(format: "U+%04X", $0.value) }
            .joined(separator: " ")
    }
}