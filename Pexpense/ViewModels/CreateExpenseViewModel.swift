//
//  CreateExpenseViewModel.swift
//  Pexpense
//

import Foundation
import Observation

/// ViewModel managing expense creation, category loading, field validation, and idempotency.
@Observable
@MainActor
final class CreateExpenseViewModel {
    private let expenseService: any ExpenseServiceProtocol
    private let coordinator: ExpenseSubmissionCoordinator
    private let onSuccess: () -> Void

    // Form fields
    var description: String = ""
    var amountString: String = ""
    var currency: String = "CHF"
    var expenseDate: Date = Date()
    var selectedCategoryId: String? = nil
    var paymentMethod: String = "card"
    var isRecurring: Bool = false
    var recurringDayOfMonth: Int = 1

    // State & Feedback
    var categories: [Components.Schemas.Category] = []
    var isLoadingCategories: Bool = false
    var isSubmitting: Bool = false
    var generalErrorMessage: String? = nil
    var fieldErrors: [String: String] = [:]

    // Payment methods available
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
        expenseService: any ExpenseServiceProtocol,
        coordinator: ExpenseSubmissionCoordinator? = nil,
        onSuccess: @escaping () -> Void
    ) {
        self.expenseService = expenseService
        self.coordinator = coordinator ?? ExpenseSubmissionCoordinator(expenseService: expenseService)
        self.onSuccess = onSuccess
    }

    /// Loads available categories from the backend.
    func loadCategories() async {
        isLoadingCategories = true
        do {
            self.categories = try await expenseService.fetchCategories()
            self.isLoadingCategories = false
        } catch {
            self.isLoadingCategories = false
            // Non-blocking: categories are optional
        }
    }

    /// Submits the expense creation request.
    func submitExpense() async {
        fieldErrors.removeAll()
        generalErrorMessage = nil

        let trimmedDesc = description.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedDesc.isEmpty {
            fieldErrors["description"] = "Description is required."
        }

        // Parse amount in units handling decimal comma or dot
        guard let amountValue = parseAmount(amountString), amountValue > 0 else {
            fieldErrors["amount"] = "Enter a valid amount greater than 0."
            return
        }

        if !fieldErrors.isEmpty {
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        let dateString = dateFormatter.string(from: expenseDate)

        let params = CreateExpenseParams(
            description: trimmedDesc,
            amountInUnits: amountValue,
            currency: currency,
            expenseDate: dateString,
            paymentMethod: paymentMethod.isEmpty ? nil : paymentMethod,
            categoryId: selectedCategoryId,
            isRecurring: isRecurring ? true : nil,
            recurringDayOfMonth: isRecurring ? recurringDayOfMonth : nil
        )

        isSubmitting = true

        do {
            _ = try await coordinator.submit(params: params)
            isSubmitting = false
            onSuccess()
        } catch let apiError as AppApiError {
            isSubmitting = false
            handleApiError(apiError)
        } catch {
            isSubmitting = false
            generalErrorMessage = "Network error. Please try again (your submission is protected against duplicates)."
        }
    }

    /// Handles structured API errors matching `code` and `field`.
    private func handleApiError(_ error: AppApiError) {
        switch error.code {
        case "VALIDATION_ERROR":
            if let field = error.field {
                fieldErrors[field] = error.message
            } else {
                generalErrorMessage = error.message
            }
        case "IDEMPOTENCY_KEY_REUSED":
            generalErrorMessage = "Request conflict detected. A new key has been assigned. Please submit again."
        case "IDEMPOTENCY_IN_PROGRESS":
            generalErrorMessage = "Your submission is already being processed. Please wait a moment."
        default:
            generalErrorMessage = error.message
        }
    }

    /// Converts user input string (handling '.' and ',') to units as Double.
    private func parseAmount(_ string: String) -> Double? {
        let cleaned = string
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: ",", with: ".")
        return Double(cleaned)
    }
}
