//
//  EditExpenseViewModel.swift
//  Pexpense
//

import Foundation
import Observation

/// ViewModel managing partial expense editing.
///
/// Money rule:
/// Expense arrives from server with `amount` in CENTIMES (Int).
/// To populate the form field for the user to edit, we convert to UNITS by dividing by 100:
/// e.g. 341100 centimes -> "3411.00", 2500 centimes -> "25.00".
/// When saving, only changed fields are sent in PATCH, with `amount` in UNITS (Double).
@Observable
@MainActor
final class EditExpenseViewModel {
    private let expenseService: any ExpenseServiceProtocol
    private let expenseId: String
    private let onSuccess: () -> Void

    // Original values to compute partial diff
    private let originalDescription: String
    private let originalAmountInUnits: Double
    private let originalCurrency: String
    private let originalDateString: String
    private let originalPaymentMethod: String?
    private let originalCategoryId: String?

    // Form fields editable by user
    var description: String
    var amountString: String
    var currency: String
    var expenseDate: Date
    var selectedCategoryId: String?
    var paymentMethod: String

    // Categories and UI state
    var categories: [Components.Schemas.Category] = []
    var isLoadingCategories: Bool = false
    var isSubmitting: Bool = false
    var generalErrorMessage: String? = nil
    var fieldErrors: [String: String] = [:]

    let paymentMethods = [
        ("card", "Card"),
        ("cash", "Cash"),
        ("twint", "TWINT"),
        ("transfer", "Bank Transfer"),
        ("invoice", "Invoice"),
        ("other", "Other")
    ]

    let currencies = ["CHF", "EUR"]

    init(
        expense: Components.Schemas.ExpenseList.expensesPayloadPayload,
        expenseService: any ExpenseServiceProtocol,
        onSuccess: @escaping () -> Void
    ) {
        self.expenseId = expense.id
        self.expenseService = expenseService
        self.onSuccess = onSuccess

        // Convert centimes to units for display: 341100 -> 3411.00
        let units = Double(expense.amount) / 100.0
        let formattedAmountUnits = String(format: "%.2f", units)

        self.originalDescription = expense.description
        self.originalAmountInUnits = units
        self.originalCurrency = expense.currency
        self.originalDateString = expense.expenseDate
        self.originalPaymentMethod = expense.paymentMethod
        self.originalCategoryId = expense.categoryId

        self.description = expense.description
        self.amountString = formattedAmountUnits
        self.currency = expense.currency
        self.selectedCategoryId = expense.categoryId
        self.paymentMethod = expense.paymentMethod ?? "card"

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        self.expenseDate = df.date(from: expense.expenseDate) ?? Date()
    }

    /// Helper converting centimes to the unit string format used by the form.
    static func formatCentimesForFormInput(_ centimes: Int) -> String {
        let units = Double(centimes) / 100.0
        return String(format: "%.2f", units)
    }

    func loadCategories() async {
        isLoadingCategories = true
        do {
            self.categories = try await expenseService.fetchCategories()
            self.isLoadingCategories = false
        } catch {
            self.isLoadingCategories = false
        }
    }

    func save() async {
        fieldErrors.removeAll()
        generalErrorMessage = nil

        let trimmedDesc = description.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedDesc.isEmpty {
            fieldErrors["description"] = "Description is required."
        }

        guard let amountValue = parseAmount(amountString), amountValue > 0 else {
            fieldErrors["amount"] = "Enter a valid amount greater than 0."
            return
        }

        if !fieldErrors.isEmpty {
            return
        }

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        let dateString = df.string(from: expenseDate)

        // Compute partial diff: only send changed fields
        var params = UpdateExpenseParams()
        var hasChanges = false

        if trimmedDesc != originalDescription {
            params.description = trimmedDesc
            hasChanges = true
        }

        // Compare rounded cents to prevent double precision noise
        if abs(amountValue - originalAmountInUnits) >= 0.005 {
            params.amountInUnits = amountValue
            hasChanges = true
        }

        if currency != originalCurrency {
            params.currency = currency
            hasChanges = true
        }

        if dateString != originalDateString {
            params.expenseDate = dateString
            hasChanges = true
        }

        let pm = paymentMethod.isEmpty ? nil : paymentMethod
        if pm != originalPaymentMethod {
            params.paymentMethod = pm
            hasChanges = true
        }

        if selectedCategoryId != originalCategoryId {
            params.categoryId = selectedCategoryId
            hasChanges = true
        }

        guard hasChanges else {
            // Nothing changed, dismiss directly
            onSuccess()
            return
        }

        isSubmitting = true

        do {
            try await expenseService.updateExpense(id: expenseId, params: params)
            isSubmitting = false
            onSuccess()
        } catch let apiError as AppApiError {
            isSubmitting = false
            switch apiError.code {
            case "VALIDATION_ERROR":
                if let field = apiError.field {
                    fieldErrors[field] = apiError.message
                } else {
                    generalErrorMessage = apiError.message
                }
            case "NOT_FOUND_EXPENSE":
                generalErrorMessage = "This expense no longer exists."
            default:
                generalErrorMessage = apiError.message
            }
        } catch {
            isSubmitting = false
            generalErrorMessage = "Network error. Please try again."
        }
    }

    private func parseAmount(_ string: String) -> Double? {
        let cleaned = string
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: ",", with: ".")
        return Double(cleaned)
    }
}
