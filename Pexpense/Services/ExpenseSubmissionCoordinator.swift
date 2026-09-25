//
//  ExpenseSubmissionCoordinator.swift
//  Pexpense
//

import Foundation

/// Coordinator responsible for tracking, persisting and executing expense creation operations.
///
/// Rules (AGENTS.md §6):
/// - A single unique `Idempotency-Key` (UUID) is generated when the user confirms the operation.
/// - The operation (key + body) is persisted to storage BEFORE the network call goes out.
/// - The EXACT same key is reused in every retry of that operation.
/// - Upon 2xx success: the pending operation is cleared from storage.
/// - On network failure / timeout: the pending operation is kept in storage for user retry or launch replay.
/// - If a 409 `IDEMPOTENCY_KEY_REUSED` occurs (body mismatch / app bug), a new key is generated for the next attempt.
/// - If a 409 `IDEMPOTENCY_IN_PROGRESS` occurs, the current key is preserved and retried.
/// - On app launch, pending operations older than 12 hours (client TTL < server 24h retention) are discarded.
@MainActor
final class ExpenseSubmissionCoordinator {
    /// Client TTL (12 hours) before discarding a pending operation to prevent duplicate creation on the server.
    static let maxPendingAge: TimeInterval = 12 * 60 * 60 // 12 hours in seconds

    private let expenseService: any ExpenseServiceProtocol
    private let pendingStore: any PendingExpenseStore
    private let dateProvider: @Sendable () -> Date

    /// The idempotency key assigned to the currently pending/in-progress submission.
    private(set) var currentIdempotencyKey: String?
    /// The parameters of the currently pending submission.
    private(set) var currentParams: CreateExpenseParams?

    init(
        expenseService: any ExpenseServiceProtocol,
        pendingStore: any PendingExpenseStore = UserDefaultsPendingExpenseStore(),
        dateProvider: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.expenseService = expenseService
        self.pendingStore = pendingStore
        self.dateProvider = dateProvider

        // Restore any existing valid pending operation from storage
        if let stored = pendingStore.loadPendingOperation() {
            let age = dateProvider().timeIntervalSince(stored.createdAt)
            if age < Self.maxPendingAge && age >= 0 {
                self.currentIdempotencyKey = stored.idempotencyKey
                self.currentParams = stored.params
            } else {
                pendingStore.clearPendingOperation()
            }
        }
    }

    /// Prepares or retrieves the idempotency key for the given parameters and persists it.
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
    /// Invariant 1: Persists the operation (key + body) BEFORE making the network call.
    @discardableResult
    func submit(params: CreateExpenseParams) async throws -> Components.Schemas.CreateExpenseResponse {
        let key = prepareIdempotencyKey(for: params)

        // 1. Gravar antes de enviar: persiste antes da chamada de rede
        let pending = PendingExpenseOperation(
            idempotencyKey: key,
            params: params,
            createdAt: dateProvider()
        )
        pendingStore.savePendingOperation(pending)

        do {
            let response = try await expenseService.createExpense(params: params, idempotencyKey: key)
            // 2. Limpar no sucesso: 2xx recebido -> apaga a operação pendente
            clear()
            return response
        } catch let apiError as AppApiError {
            if apiError.code == "IDEMPOTENCY_KEY_REUSED" {
                // Bug do app: mesma chave com corpo diferente -> invalida a chave e pendencia
                clear()
            }
            // 3. Manter na falha: outros erros (IDEMPOTENCY_IN_PROGRESS, etc.) mantêm a chave
            throw apiError
        } catch {
            // 3. Manter na falha: erro de rede/timeout mantém a operação e a chave para retry
            throw error
        }
    }

    /// Replays any stored pending operation on app launch if within the 12h TTL.
    /// Returns true if a pending operation was found and replayed.
    @discardableResult
    func replayPendingOperationIfNeeded() async -> Bool {
        guard let stored = pendingStore.loadPendingOperation() else {
            return false
        }

        let age = dateProvider().timeIntervalSince(stored.createdAt)
        // 5. TTL do cliente (12h): se mais velha que 12h, descarta e NÃO replique
        guard age < Self.maxPendingAge && age >= 0 else {
            clear()
            return false
        }

        self.currentIdempotencyKey = stored.idempotencyKey
        self.currentParams = stored.params

        do {
            _ = try await expenseService.createExpense(params: stored.params, idempotencyKey: stored.idempotencyKey)
            clear()
            return true
        } catch let apiError as AppApiError where apiError.code == "IDEMPOTENCY_KEY_REUSED" {
            clear()
            return false
        } catch {
            // If still failing with network issue, remains stored for next retry/launch
            return false
        }
    }

    /// Resets the current operation state both in memory and in persistent storage.
    func clear() {
        self.currentIdempotencyKey = nil
        self.currentParams = nil
        pendingStore.clearPendingOperation()
    }
}
