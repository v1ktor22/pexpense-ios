//
//  ExpenseDisplay.swift
//  Pexpense
//

import Foundation

/// Presentation model representing an expense row in the UI.
///
/// Decouples raw OpenAPI models from view rendering and ensures proper money formatting.
struct ExpenseDisplay: Identifiable, Equatable, Sendable {
    let id: String
    let description: String
    let formattedAmount: String
    let formattedDate: String
    let categoryName: String?
    let categoryColor: String?

    init(
        id: String,
        description: String,
        amountInCentimes: Int,
        currencyCode: String,
        expenseDate: String,
        categoryName: String? = nil,
        categoryColor: String? = nil
    ) {
        self.id = id
        self.description = description
        let currency = CurrencyFormatter.Currency(rawValue: currencyCode) ?? .chf
        self.formattedAmount = CurrencyFormatter.string(fromMinorUnits: amountInCentimes, currency: currency)
        self.formattedDate = expenseDate
        self.categoryName = categoryName
        self.categoryColor = categoryColor
    }

    init(from schemaItem: Components.Schemas.ExpenseList.expensesPayloadPayload) {
        self.init(
            id: schemaItem.id,
            description: schemaItem.description,
            amountInCentimes: schemaItem.amount,
            currencyCode: schemaItem.currency,
            expenseDate: schemaItem.expenseDate,
            categoryName: schemaItem.categoryName,
            categoryColor: schemaItem.categoryColor
        )
    }
}
