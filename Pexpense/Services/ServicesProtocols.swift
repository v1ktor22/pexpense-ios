//
//  ServicesProtocols.swift
//  Pexpense
//

import Foundation
import OpenAPIRuntime

/// Protocol abstracting authentication actions.
protocol AuthenticationService: Sendable {
    /// Requests an OTP login code sent to the specified email.
    func requestOTP(email: String) async throws -> RequestOTPResult

    /// Exchanges email and OTP code for device tokens.
    func verifyOTP(email: String, code: String) async throws -> Components.Schemas.TokenPair

    /// Revokes current device token.
    func logout() async throws
}

enum RequestOTPResult: Sendable {
    case sent
    case cooldown(seconds: Int)
}

/// Protocol abstracting expense retrieval actions.
protocol ExpenseServiceProtocol: Sendable {
    /// Fetches expenses with summary for a given period.
    func fetchExpenses(limit: Int?) async throws -> Components.Schemas.ExpenseList

    /// Fetches available categories.
    func fetchCategories() async throws -> [Components.Schemas.Category]

    /// Creates an expense with idempotency key tracking.
    func createExpense(
        params: CreateExpenseParams,
        idempotencyKey: String
    ) async throws -> Components.Schemas.CreateExpenseResponse

    /// Partially updates an existing expense.
    func updateExpense(
        id: String,
        params: UpdateExpenseParams
    ) async throws

    /// Deletes an expense by its ID.
    func deleteExpense(id: String) async throws
}

/// Parameters for partially updating an expense.
/// Note: Only provided fields will be sent in the PATCH request.
/// `amountInUnits` is in UNIDADES (ex: 12.50 = CHF 12.50), not in centimes.
struct UpdateExpenseParams: Sendable, Equatable {
    var description: String?
    var amountInUnits: Double?
    var currency: String?
    var expenseDate: String? // YYYY-MM-DD
    var paymentMethod: String?
    var categoryId: String?
}

/// Parameters for creating an expense.
/// Note: `amountInUnits` is in UNIDADES (ex: 12.50 = CHF 12.50), not in centimes.
struct CreateExpenseParams: Codable, Sendable, Equatable {
    var description: String
    var amountInUnits: Double
    var currency: String
    var expenseDate: String // YYYY-MM-DD
    var paymentMethod: String?
    var categoryId: String?
    var isRecurring: Bool?
    var recurringDayOfMonth: Int?
}

/// High-level API error parsed from server JSON `{ code, error, field?, rule? }`.
struct AppApiError: Error, LocalizedError, Sendable {
    let code: String
    let message: String
    let field: String?
    let rule: String?

    init(code: String, message: String, field: String? = nil, rule: String? = nil) {
        self.code = code
        self.message = message
        self.field = field
        self.rule = rule
    }

    var errorDescription: String? {
        message
    }
}
