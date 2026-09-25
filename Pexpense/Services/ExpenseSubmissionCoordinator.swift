//
//  ExpenseSubmissionCoordinator.swift
//  Pexpense
//

import Foundation

/// Coordinator responsible for tracking and executing expense creation operations.
///
/// Rules (AGENTS.md §6):
/// - A single unique `Idempotency-Key` (UUID) is generated when the user confirms the operation.
/// - The EXACT same key is reused in every retry of that operation.
/// - If a 409 `IDEMPOTENCY_KEY_REUSED` occurs (body mismatch / app bug), a new key is generated for the next attempt.
/// - If a 409 `IDEMPOTENCY_IN_PROGRESS` occurs, the current key is preserved and retried.
/// - Upon success, the tracked key and parameters are cleared.
@MainActor
final class ExpenseSubmissionCoordinator {
    private let expenseService: any ExpenseServiceProtocol

    /// The idempotency key assigned to the currently pending/in-progress submission.
    private(set) var currentIdempotencyKey: String?
    /// The parameters of the currently pending submission.
    private(set) var currentParams: CreateExpenseParams?

    init(expenseService: any ExpenseServiceProtocol) {
        self.expenseService = expenseService
    }

    /// Prepares or retrieves the idempotency key for the given parameters.
    /// If params match the current pending operation, the existing key is retained (retry).
    /// If params are new or changed, a new idempotency key is generated.
    func prepareIdempotencyKey(for params: CreateExpenseParams) -> String {
        if let existingKey = currentIdempotencyKey, currentParams == params {
            return existingKey
        }
        let newKey = UUID().uuidString
        self.currentIdempotencyKey = newKey
        self.currentParams = params
        return newKey
    }

    /// Submits the expense using the tracked idempotency key.
    @discardableResult
    func submit(params: CreateExpenseParams) async throws -> Components.Schemas.CreateExpenseResponse {
        let key = prepareIdempotencyKey(for: params)

        do {
            let response = try await expenseService.createExpense(params: params, idempotencyKey: key)
            // Success: clear tracked operation
            clear()
            return response
        } catch let apiError as AppApiError {
            if apiError.code == "IDEMPOTENCY_KEY_REUSED" {
                // Bug: same key with different body. Invalidate key for future retry.
                self.currentIdempotencyKey = nil
            }
            // For IDEMPOTENCY_IN_PROGRESS or network/validation errors, key remains stored for retry.
            throw apiError
        } catch {
            // Network failure: keep key for subsequent retry
            throw error
        }
    }

    /// Resets the current operation state.
    func clear() {
        self.currentIdempotencyKey = nil
        self.currentParams = nil
    }
}
